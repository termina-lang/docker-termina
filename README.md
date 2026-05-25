# docker-termina

Docker image for Termina development: transpiler, OSAL, and embedded
cross-toolchains.

This repository builds a ready-to-use container image bundling everything
needed to write, transpile, and run [Termina](https://github.com/termina-lang/termina)
programs without installing anything on the host beyond Docker itself.
It is intended to be the easiest on-ramp for students, researchers, and
external contributors.

## Status

**Work in progress.** The repository scaffold is in place; the `Dockerfile`
and the GitHub Actions workflow that publishes images to GHCR will land
in subsequent commits. See [`CHANGELOG.md`](./CHANGELOG.md) for the history.

## What the image will bundle

- The Termina transpiler ([`termina`](https://github.com/termina-lang/termina)).
- The Termina OSAL ([`termina-osal`](https://github.com/termina-lang/termina-osal)).
- Cross-toolchains for embedded targets: Gaisler `sparc-rtems5-gcc` for the
  LEON/RTEMS path, `arm-none-eabi-gcc` for STM32 and similar bare-metal ARM
  targets.
- `qemu-system-sparc` for running RTEMS images without hardware.
- The Termina VS Code extension preinstalled, so Dev Containers users get
  syntax support and the language server out of the box.

The image targets `linux/amd64`. On Apple Silicon, run Docker Desktop with
Rosetta enabled.

## Versioning

The image version tracks the Termina transpiler and the OSAL at the
`MAJOR.MINOR` level. See [`CHANGELOG.md`](./CHANGELOG.md) for the exact
versions bundled by each release.

## License

MIT. See [`LICENSE`](./LICENSE).
