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

## [0.6.0] - 2026-10-15

### Added

- RTEMS 6.2 for ARM, for the `rtems6-zynq7000-pynqz2` platform: the
  `arm-rtems6` toolchain of the RTEMS Source Builder and the
  `xilinx_zynq_pynq` BSP, with the kernel console on UART 0
  (`rtems/config.ini`). The kernel is built in `/opt/rtems/6/src`, which keeps
  the sources of cpukit and of the Zynq BSP for GDB.
- The GDB support of RTEMS 6 for `gdb-multiarch`, which runs the scripts of the
  ELF files of the projects under `/workspaces`.
- MAST `1.6.0.1` (`mast_analysis`), for `termina sched`.
- cppcheck `2.21.1` with its MISRA addon, built from its tag. The cppcheck of
  Ubuntu 24.04 reports false `duplicateCondition` findings.
- `lcov`.
- The build arguments `TERMINA_REF` and `OSAL_REF`, which build the image from
  a branch instead of the release tag.

### Changed

- Bundle Termina transpiler `v0.6.0` and Termina OSAL `v0.6.0`, which add
  calls to C functions, run-time checks of arithmetic, the value analysis and
  the `rtems6-zynq7000-pynqz2` platform, and move the generated C to the
  `termina` namespace. The image minor is bumped to `0.6` to track the
  `MAJOR.MINOR` of the bundled stack.
- `arm-none-eabi-gcc` comes from the Arm GNU Toolchain `13.3.rel1`, the release
  that STM32CubeCLT ships, instead of the `gcc-arm-none-eabi` package of
  Ubuntu. The package does not include newlib, and no project for
  `freertos10-stm32l432-nucleol432kc` compiled in the image.
- The cross-toolchains keep only the multilibs of the image platforms
  (`thumb/armv7-a+simd/hard` for RTEMS 6, `soft/leon3` for RCC and
  `thumb/v7e-m+fp/hard` for Arm), without C++, Fortran, LTO, their own GDB or
  their documentation. RCC keeps the `leon3` and `leon3_sf` BSPs and the
  sources of RTEMS 5 for LEON3. The image goes from 7.86 GB to 1.65 GB.
- `build-essential` is replaced by `gcc` and `libc6-dev`, and `vim` by
  `vim-tiny`.

### Removed

- **BREAKING**: `qemu-system-sparc` and the stage that built it. Emulators run
  on the host; `gdb` and `gdb-multiarch` stay in the image, where an editor
  attached to the container runs them.

## [0.5.0] - 2026-06-19

### Changed

- Bundle Termina transpiler `v0.5.0` and Termina OSAL `v0.5.0`, which make the
  system port's `print`/`read` buffers fixed-size and configurable. The image
  minor is bumped to `0.5` to track the `MAJOR.MINOR` of the bundled stack.


## [0.4.0] - 2026-06-18

### Changed

- Bundle Termina transpiler `v0.4.0` (was `v0.3.4`) and Termina OSAL `v0.4.0`
  (was `v0.3.1`), which add the `f32`/`f64` floating-point types and remove
  variable-length arrays. The image minor is bumped to `0.4` to track the
  `MAJOR.MINOR` of the bundled stack.


## [0.3.2] - 2026-05-27

### Added

- `gdb` and `gdb-multiarch`, for debugging native and cross-compiled programs.

### Changed

- Bundle Termina transpiler `v0.3.4` (was `v0.3.3`). The OSAL remains at `v0.3.1`.


## [0.3.1] - 2026-05-26

### Changed

- Bundle Termina transpiler `v0.3.3` (was `v0.3.2`), which fixes an internal
  error for resources reached only through an unprotected resource. The OSAL
  remains at `v0.3.1`.


## [0.3.0] - 2026-05-26

Initial tagged release of the docker-termina image.

### Added

- Repository scaffold (README, LICENSE, VERSION, CHANGELOG, ignore files).
- `Dockerfile` building a three-stage image:
  - Stage 1 compiles the Termina transpiler from source at the pinned tag
    `v0.3.2` using the official `haskell:9.6.7-bullseye` image.
  - Stage 2 builds upstream QEMU `9.2.4` from source with a single-line
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
