# docker-termina

Docker image for Termina development: transpiler, OSAL, and embedded
cross-toolchains.

This repository builds a ready-to-use container image bundling everything
needed to write, transpile, and run [Termina](https://github.com/termina-lang/termina)
programs without installing anything on the host beyond Docker itself.
It is intended to be the easiest on-ramp for researchers, collaborators,
external contributors, and students working on or with Termina.

## Status

The `Dockerfile` is in place and builds a functional image locally. The
GitHub Actions workflow that publishes images to GHCR will land in a
follow-up commit; the first tagged release (`v0.3.0`) will be cut once
the CI pipeline is wired and the build is verified end-to-end. See
[`CHANGELOG.md`](./CHANGELOG.md) for the history.

## Building locally

```sh
docker build --platform linux/amd64 -t docker-termina:dev .
```

First build takes ~25-30 minutes on a fresh machine (Haskell toolchain
download, transpiler compilation, QEMU compilation). Subsequent builds
that touch only the runtime stage take a couple of minutes.

## Using as a Dev Container

In a Termina project, add `.devcontainer/devcontainer.json`:

```jsonc
{
  "name": "Termina dev container",
  "image": "ghcr.io/termina-lang/docker-termina:v0.3.0",
  "customizations": {
    "vscode": {
      "extensions": ["termina-lang.termina"]
    }
  },
  "remoteUser": "vscode"
}
```

Open the project in VS Code Desktop with the Dev Containers extension
installed and choose *Reopen in Container*.

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
