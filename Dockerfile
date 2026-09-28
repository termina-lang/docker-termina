# syntax=docker/dockerfile:1.7
#
# docker-termina image build.
#
# Layered as two stages: a Haskell builder that compiles the Termina
# transpiler from source, and a Ubuntu runtime that bundles toolchains,
# OSAL and transpiler binary. The builder stage exists only to keep its
# heavyweight dependencies (GHC, stack store, ~5 GB) out of the published
# image.
#
# Emulators, and anything else that stands in for a board, run on the
# host. The debuggers stay here, because an editor attached to the
# container runs them inside it.
#
# All inputs are pinned: explicit versions for the transpiler and the
# OSAL via git tag, a SHA256 hash for the Gaisler RCC tarball, which is
# mirrored on this repository's "toolchains" release.
#
# Target platform is linux/amd64 only. The Gaisler RCC binaries are
# distributed exclusively for x86_64 Linux; emulation under Rosetta
# (Apple Silicon) or Prism (Windows on ARM) covers the rest.

# -----------------------------------------------------------------------------
# Global build arguments. Defaults pin the stack shipped by this Dockerfile
# release; CI may override individual values for experimental builds.
# -----------------------------------------------------------------------------
ARG UBUNTU_VERSION=24.04
ARG HASKELL_IMAGE=haskell:9.6.7-bullseye

ARG TERMINA_VERSION=0.5.0
ARG OSAL_VERSION=0.5.0

ARG RCC_VERSION=1.3.2
ARG RCC_GCC=10.5.0
ARG RCC_SHA256=f1ec95244898b015e153acd881c2489a0f53b7451170159ab49e5ac7d1a9d25c


# =============================================================================
# Stage 1: Termina transpiler builder
#
# Uses the official Haskell image (GHC 9.6.7 + stack pre-installed). Stack
# itself manages the exact GHC required by stack.yaml (LTS-22.43 → GHC 9.6.6)
# inside ~/.stack, irrespective of which patch level the image ships.
# Clones the transpiler repo at the pinned tag, builds, and copies the
# stripped binary to /out.
# =============================================================================
FROM --platform=linux/amd64 ${HASKELL_IMAGE} AS termina-builder

ARG TERMINA_VERSION

WORKDIR /build

RUN git clone --depth 1 --branch "v${TERMINA_VERSION}" \
        https://github.com/termina-lang/termina.git . \
 && stack build \
        --system-ghc \
        --copy-bins \
        --local-bin-path /out \
 && strip /out/termina


# =============================================================================
# Stage 2: Runtime image (the one users pull)
#
# Layers ordered from least frequently to most frequently changing, so
# users updating the image only pay for the delta of the top layers.
# =============================================================================
FROM --platform=linux/amd64 ubuntu:${UBUNTU_VERSION}

ARG OSAL_VERSION
ARG RCC_VERSION
ARG RCC_GCC
ARG RCC_SHA256

LABEL org.opencontainers.image.source="https://github.com/termina-lang/docker-termina" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="docker-termina" \
      org.opencontainers.image.description="Docker image for Termina development: transpiler, OSAL, and embedded cross-toolchains."

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# --- Base system tooling + ARM cross-toolchain -------------------------------
#
# Kept in a single apt invocation so the layer is one cohesive unit:
# inspectable and invalidated as a whole when the package list changes.
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
        build-essential \
        ca-certificates \
        curl \
        gcc-arm-none-eabi \
        gdb \
        gdb-multiarch \
        git \
        less \
        make \
        nano \
        python3 \
        sudo \
        vim \
        xz-utils \
 && rm -rf /var/lib/apt/lists/*

# --- Gaisler RCC toolchain (sparc-gaisler-rtems5-gcc) ------------------------
#
# Mirrored on this repository's "toolchains" release to insulate the build
# from upstream URL changes. SHA256 is pinned; any drift fails the build
# deterministically. The tarball top-level directory is rcc-X.Y.Z-gcc/,
# extracted directly under /opt. A /opt/rcc symlink decouples consumers
# (Makefiles, OSAL platform.mk) from the exact version on disk.
RUN set -eux; \
    curl -fSL -o /tmp/rcc.txz \
        "https://github.com/termina-lang/docker-termina/releases/download/toolchains/sparc-rtems-5-gcc-${RCC_GCC}-${RCC_VERSION}-linux.txz"; \
    echo "${RCC_SHA256}  /tmp/rcc.txz" | sha256sum -c -; \
    tar -xJf /tmp/rcc.txz -C /opt/; \
    ln -s "/opt/rcc-${RCC_VERSION}-gcc" /opt/rcc; \
    rm /tmp/rcc.txz

# --- Dev Containers user -----------------------------------------------------
#
# Non-root user with UID 1000 and passwordless sudo, the convention VS Code
# Dev Containers expects. On Linux hosts, "updateRemoteUserUID" in
# devcontainer.json remaps this to the host UID so bind-mounted files stay
# writable. On Mac/Windows the Docker VM handles ownership translation.
RUN userdel --remove ubuntu 2>/dev/null || true \
 && groupadd --gid 1000 vscode \
 && useradd --uid 1000 --gid vscode --shell /bin/bash --create-home vscode \
 && echo "vscode ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vscode \
 && chmod 0440 /etc/sudoers.d/vscode

# --- Termina OSAL sources ----------------------------------------------------
#
# Source tree consumed at build time by user applications. The Makefile of
# each application sets TERMINA_OSAL_DIR and includes the platform.mk that
# corresponds to its target.
RUN git clone --depth 1 --branch "v${OSAL_VERSION}" \
        https://github.com/termina-lang/termina-osal.git /opt/termina-osal \
 && rm -rf /opt/termina-osal/.git

# --- Termina transpiler binary -----------------------------------------------
#
# Last substantial layer so that transpiler bumps only invalidate this one.
COPY --from=termina-builder /out/termina /usr/local/bin/termina

# --- Environment -------------------------------------------------------------
ENV TERMINA_OSAL_DIR=/opt/termina-osal \
    PATH=/opt/rcc/bin:${PATH}

USER vscode
WORKDIR /home/vscode

CMD ["bash"]
