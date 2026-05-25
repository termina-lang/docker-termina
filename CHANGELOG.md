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
  files). The `Dockerfile` and the CI workflow will follow; the first
  tagged release (`v0.3.0`) will be cut when the image actually bundles
  the Termina stack.
