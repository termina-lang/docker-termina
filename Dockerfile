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

ARG TERMINA_VERSION=0.6.0
ARG OSAL_VERSION=0.6.0
# Branch or tag to build from; a test image may point them at main
ARG TERMINA_REF=v${TERMINA_VERSION}
ARG OSAL_REF=v${OSAL_VERSION}

ARG RCC_VERSION=1.3.2
ARG RCC_GCC=10.5.0
ARG RCC_SHA256=f1ec95244898b015e153acd881c2489a0f53b7451170159ab49e5ac7d1a9d25c

ARG RTEMS_VERSION=6.2
ARG RTEMS_URL=https://ftp.rtems.org/pub/rtems/releases/6/6.2/sources
ARG RTEMS_SHA256=0a15c2f9f6ab81b7da3e8240a8bbaa2da45be62b6b050a6197b145ac58eaedce
ARG RSB_SHA256=33dd224ff8ac4491bf182a31436d76b1981508f4cb48feb3a16aeb540530d124

ARG ARM_GNU_VERSION=13.3.rel1
ARG ARM_GNU_URL=https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel
ARG ARM_GNU_SHA256=95c011cee430e64dd6087c75c800f04b9c49832cc1000127a92a97f9c8d83af4

ARG MAST_VERSION=1-6-0-1
ARG MAST_URL=https://github.com/termina-lang/docker-termina/releases/download/toolchains
ARG MAST_SHA256=9fbea0b9f83db4fb3acfe770832733ed47ac54a96a2ce0818ea81fa3de99f359

ARG CPPCHECK_VERSION=2.21.1


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

ARG TERMINA_REF

WORKDIR /build

RUN git clone --depth 1 --branch "${TERMINA_REF}" \
        https://github.com/termina-lang/termina.git . \
 && stack build \
        --system-ghc \
        --copy-bins \
        --local-bin-path /out \
 && strip /out/termina


# =============================================================================
# Stage 2: RTEMS 6 for ARM
#
# The tools come from the RTEMS Source Builder of the release, the board
# support packages from the kernel of the release with config.ini.
# =============================================================================
FROM --platform=linux/amd64 ubuntu:${UBUNTU_VERSION} AS rtems6-builder

ARG RTEMS_VERSION
ARG RTEMS_URL
ARG RTEMS_SHA256
ARG RSB_SHA256

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install --no-install-recommends -y \
        bison \
        build-essential \
        bzip2 \
        ca-certificates \
        curl \
        flex \
        git \
        libncurses-dev \
        patch \
        python3 \
        python3-dev \
        python-is-python3 \
        texinfo \
        unzip \
        xz-utils \
        zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN set -eux; \
    curl -fSL -o rsb.txz "${RTEMS_URL}/rtems-source-builder-${RTEMS_VERSION}.tar.xz"; \
    echo "${RSB_SHA256}  rsb.txz" | sha256sum -c -; \
    tar -xJf rsb.txz; \
    cd "rtems-source-builder-${RTEMS_VERSION}/rtems"; \
    ../source-builder/sb-set-builder --prefix=/opt/rtems/6 \
        --jobs="$(nproc)" 6/rtems-arm

COPY rtems/config.ini /build/config.ini
COPY scripts/ /build/scripts/

# Built under the prefix, so that the debug information of the BSP points to
# sources that the image keeps
RUN set -eux; \
    curl -fSL -o rtems.txz "${RTEMS_URL}/rtems-${RTEMS_VERSION}.tar.xz"; \
    echo "${RTEMS_SHA256}  rtems.txz" | sha256sum -c -; \
    mkdir -p /opt/rtems/6/src; \
    tar -xJf rtems.txz -C /opt/rtems/6/src; \
    cd "/opt/rtems/6/src/rtems-${RTEMS_VERSION}"; \
    export PATH=/opt/rtems/6/bin:${PATH}; \
    ./waf configure --rtems-config=/build/config.ini --prefix=/opt/rtems/6; \
    ./waf; \
    ./waf install

# The GDB support of RTEMS goes to the gdb-multiarch of the runtime image
RUN set -eux; \
    mkdir -p /build/gdb-python; \
    cp -r /opt/rtems/6/share/gdb/python/rtems /build/gdb-python/; \
    sh /build/scripts/slim-toolchain.sh /opt/rtems/6 arm-rtems6 \
        thumb/armv7-a+simd/hard; \
    sh /build/scripts/slim-rtems-src.sh \
        "/opt/rtems/6/src/rtems-${RTEMS_VERSION}" arm xilinx-zynq


# =============================================================================
# Stage 3: cppcheck, built from its tag (the one of apt reports false
# duplicateCondition findings)
# =============================================================================
FROM --platform=linux/amd64 ubuntu:${UBUNTU_VERSION} AS cppcheck-builder

ARG CPPCHECK_VERSION

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install --no-install-recommends -y \
        build-essential \
        ca-certificates \
        cmake \
        git \
        python3 \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    git clone --depth 1 --branch "${CPPCHECK_VERSION}" \
        https://github.com/danmar/cppcheck.git /build/cppcheck; \
    cmake -S /build/cppcheck -B /build/cppcheck/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DUSE_MATCHCOMPILER=ON \
        -DCMAKE_INSTALL_PREFIX=/opt/cppcheck \
        -DFILESDIR=/opt/cppcheck/share/cppcheck; \
    cmake --build /build/cppcheck/build -j "$(nproc)"; \
    cmake --install /build/cppcheck/build


# =============================================================================
# Stage 4: Runtime image (the one users pull)
#
# Layers ordered from least frequently to most frequently changing, so
# users updating the image only pay for the delta of the top layers.
# =============================================================================
FROM --platform=linux/amd64 ubuntu:${UBUNTU_VERSION}

ARG OSAL_REF
ARG RCC_VERSION
ARG RCC_GCC
ARG RCC_SHA256
ARG ARM_GNU_VERSION
ARG ARM_GNU_URL
ARG ARM_GNU_SHA256
ARG MAST_VERSION
ARG MAST_URL
ARG MAST_SHA256

LABEL org.opencontainers.image.source="https://github.com/termina-lang/docker-termina" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.title="docker-termina" \
      org.opencontainers.image.description="Docker image for Termina development: transpiler, OSAL, and embedded cross-toolchains."

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# --- Base system tooling -----------------------------------------------------
#
# Kept in a single apt invocation so the layer is one cohesive unit:
# inspectable and invalidated as a whole when the package list changes.
RUN apt-get update \
 && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        gcc \
        gdb \
        gdb-multiarch \
        git \
        less \
        lcov \
        libc6-dev \
        make \
        nano \
        python3 \
        sudo \
        vim-tiny \
        xz-utils \
 && rm -rf /var/lib/apt/lists/*

COPY scripts/ /tmp/scripts/

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
    rm /tmp/rcc.txz; \
    cd "/opt/rcc-${RCC_VERSION}-gcc"; \
    for d in sparc-gaisler-rtems5/*/; do \
        case $(basename "${d}") in \
            bin|include|lib|leon3|leon3_sf) ;; \
            *) rm -rf "${d}" ;; \
        esac; \
    done; \
    sh /tmp/scripts/slim-toolchain.sh "/opt/rcc-${RCC_VERSION}-gcc" \
        sparc-gaisler-rtems5 soft/leon3; \
    find src -mindepth 1 -maxdepth 1 ! -name "rcc-${RCC_VERSION}" \
        -exec rm -rf {} +; \
    sh /tmp/scripts/slim-rtems-src.sh "src/rcc-${RCC_VERSION}" sparc leon3

# --- Arm GNU Toolchain (arm-none-eabi-gcc) -----------------------------------
#
# The release of GCC that STM32CubeCLT ships, from Arm.
RUN set -eux; \
    name="arm-gnu-toolchain-${ARM_GNU_VERSION}-x86_64-arm-none-eabi"; \
    curl -fSL -o /tmp/arm.txz "${ARM_GNU_URL}/${name}.tar.xz"; \
    echo "${ARM_GNU_SHA256}  /tmp/arm.txz" | sha256sum -c -; \
    tar -xJf /tmp/arm.txz -C /opt/; \
    ln -s "/opt/${name}" /opt/arm-none-eabi; \
    rm /tmp/arm.txz; \
    sh /tmp/scripts/slim-toolchain.sh "/opt/${name}" arm-none-eabi \
        thumb/v7e-m+fp/hard

# --- MAST (mast_analysis, for termina sched) ---------------------------------
RUN set -eux; \
    curl -fSL -o /tmp/mast.tgz "${MAST_URL}/mast-bin-linux-${MAST_VERSION}.tar.gz"; \
    echo "${MAST_SHA256}  /tmp/mast.tgz" | sha256sum -c -; \
    tar -xzf /tmp/mast.tgz -C /opt/; \
    ln -s "/opt/mast-bin-linux-${MAST_VERSION}" /opt/mast; \
    ln -s /opt/mast/mast_analysis /usr/local/bin/mast_analysis; \
    rm /tmp/mast.tgz; \
    find "/opt/mast-bin-linux-${MAST_VERSION}" -mindepth 1 -maxdepth 1 \
        ! -name mast_analysis ! -name README.txt -exec rm -rf {} +; \
    rm -rf /tmp/scripts

# --- RTEMS 6 for ARM and cppcheck --------------------------------------------
COPY --from=rtems6-builder /opt/rtems/6 /opt/rtems/6
COPY --from=cppcheck-builder /opt/cppcheck /opt/cppcheck

# --- GDB support of RTEMS ----------------------------------------------------
#
# The ELF files of RTEMS 6 load it from the data directory of GDB. It looks for
# the printers of libstdc++ under the version of GCC of the toolchain, and GDB
# runs the scripts of the ELF files only under the projects in /workspaces.
COPY --from=rtems6-builder /build/gdb-python/rtems /usr/share/gdb/python/rtems
RUN set -eux; \
    v=$(sed -n 's/^gcc_version = "\(.*\)"/\1/p' \
        /usr/share/gdb/python/rtems/stdcxx.py); \
    ln -s gcc "/usr/share/gcc-${v}"; \
    echo "add-auto-load-safe-path /workspaces" \
        > /etc/gdb/gdbinit.d/termina.gdb

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
RUN git clone --depth 1 --branch "${OSAL_REF}" \
        https://github.com/termina-lang/termina-osal.git /opt/termina-osal \
 && rm -rf /opt/termina-osal/.git

# --- Termina transpiler binary -----------------------------------------------
#
# Last substantial layer so that transpiler bumps only invalidate this one.
COPY --from=termina-builder /out/termina /usr/local/bin/termina

# --- Environment -------------------------------------------------------------
ENV TERMINA_OSAL_DIR=/opt/termina-osal \
    PATH=/opt/rcc/bin:/opt/rtems/6/bin:/opt/arm-none-eabi/bin:/opt/cppcheck/bin:${PATH}

USER vscode
WORKDIR /home/vscode

CMD ["bash"]
