# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with pre-1.0 semantics: while in `0.x`, minor bumps may include breaking changes.

The image version tracks the [Termina transpiler](https://github.com/termina-lang/termina)
and the [Termina OSAL](https://github.com/termina-lang/termina-osal) at the
`MAJOR.MINOR` level. An image tagged `vA.B.Z` bundles a `termina vA.B.x` and
a `termina-osal vA.B.y` that satisfy the lockstep compatibility contract.
Patch versions on the image itself may also reflect changes that only affect
the build context (base OS bump, additional tooling) without moving the
bundled Termina stack.

## [Unreleased]

### Added

- Initial repository scaffold (README, LICENSE, VERSION, CHANGELOG, ignore
  files). The first tagged release (`v0.3.0`) will be cut once the image
  builds end-to-end on CI.
- `Dockerfile` building a three-stage image:
  - Stage 1 compiles the Termina transpiler from source at the pinned tag
    `v0.3.0` using the official `haskell:9.6.6-bookworm` image.
  - Stage 2 builds upstream QEMU 9.2.4 from source with a single-line
    patch (`patches/qemu-leon3-uart-irq.patch`) that aligns the LEON3
    UART interrupt with the Gaisler Nexys A7 reference design.
  - Stage 3 (the published image) bundles Ubuntu 24.04, the Gaisler RCC
    1.3.2 GCC toolchain (mirrored on this repo's `toolchains` release
    and SHA256-pinned), `gcc-arm-none-eabi` from the Ubuntu archive,
    the patched `qemu-system-sparc`, the Termina OSAL source at the
    pinned tag `v0.3.1`, and the Termina transpiler binary.
  - A non-root `vscode` user (UID 1000, passwordless sudo) is provisioned
    following the Dev Containers convention.
- `patches/qemu-leon3-uart-irq.patch`: portable unified diff against
  qemu-9.2.4 that changes `LEON3_UART_IRQ` from 3 to 2 in
  `hw/sparc/leon3.c`. Applies with `patch -p1`.
- GitHub Actions workflow `.github/workflows/build-and-push.yml` that
  builds the image on every `v*.*.*` tag push and publishes to
  `ghcr.io/termina-lang/docker-termina`. Image tags produced per release:
  `vX.Y.Z` (immutable, equals the git tag), `X.Y` (floating on the latest
  patch of the minor series), and `latest` (floating on the latest
  non-prerelease). Pre-release tags (`-rc*`) skip the `latest` alias.
  The workflow also supports manual triggering via `workflow_dispatch`.
