# Contributing to VolvoxGrid

Thanks for being here. Whether you're filing a bug, fixing one, or adding a feature, this doc walks you through what to expect.

For repo architecture, prerequisites, and the daily build commands, see [ARCHITECTURE.md](ARCHITECTURE.md) — this file stays focused on policy and review.

## Contributor License Agreement (CLA)

By submitting a pull request or patch to this repository, you agree to the following terms:

1. **License Grant**: You license your contribution under the Apache License 2.0, consistent with the project's LICENSE file.

2. **Original Work**: You represent that your contribution is your original work, or you have the necessary rights to submit it under these terms.

3. **No Warranty**: You provide your contribution "as is" without any warranty.

## How to report an issue

Before you open one, check the existing issue list — there's a good chance the bug or feature you're thinking about is already tracked.

When you do file, give us enough to reproduce. The shape we expect is:

- OS and version, Rust version, and the relevant SDK version (Flutter, JDK, .NET, Node, Go) for the path you hit the bug on
- Exact steps to reproduce
- The error message, log, and stack trace if there is one
- What you expected to happen, and what actually happened

For feature requests, lead with the use case — what you're trying to build and what's blocking you. That makes it much easier to design something that fits.

## How to submit code

1. Fork the repository.
2. Branch off `main` (`git checkout -b feature/your-feature`).
3. Make your change. Keep it scoped — one logical change per PR.
4. Run the relevant tests (`make test` at minimum; see [Testing](#testing) below).
5. Commit with a clear message (see the [Commit messages](#commit-messages) section).
6. Push to your fork and open a PR against `main`.
7. Make sure CI is green before requesting review.

If your change touches the public API, update the matching docs in the same PR. If it adds behavior, add a test.

## Code style

Each language follows its native conventions — don't fight the tooling.

- **Rust** — run `cargo fmt` and `cargo clippy` before submitting. Treat clippy warnings as errors unless you have a reason not to.
- **Flutter/Dart** — run `dart format .` in the Flutter directories.
- **Proto** — follow Google's protobuf style guide. Field numbers are forever, so think before you assign them.
- **Java/Kotlin** — match the surrounding file. Gradle wrappers are checked in.
- **C# / .NET** — `dotnet format` before pushing.
- **Go** — `gofmt`, `go vet`, and the usual.
- **TypeScript** — the `web/js/` package has its own lint/format setup; run it before pushing.

## Commit messages

The format is `component: short description`, with an optional body explaining the why (not the how — the code shows how).

```
component: short description

Longer explanation if needed. Explain what and why,
not how (the code shows how).
```

Real examples from the history:

- `engine: optimize cell rendering performance`
- `flutter: add support for custom cell editors`
- `web: fix wasm memory leak in grid disposal`
- `runtime: update ffi bindings for new proto fields`

Keep the subject under 72 characters. If you can't summarize the change in one line, the PR is probably doing too much.

## Local development quick links

The full prerequisites, mental model, and `make` targets live in [ARCHITECTURE.md](ARCHITECTURE.md). The short version:

```bash
# clone
git clone https://github.com/ivere27/volvoxgrid.git
cd volvoxgrid

# build the engine and native library
make build

# smoke-test the native library
make run

# run unit tests
make test

# pick the host you're working on
make web
make flutter-run
make java-desktop-run
make rust-gtk-run
make go-tui-run
make dotnet-tui-run
make java-tui-run
```

If you're changing `.proto` files, run `make codegen` before rebuilding anything.

## Project layout

```
volvoxgrid/
├── engine/           # Core grid logic (Rust)
├── runtime/          # Synurang FFI runtime wrapper and WASM targets (Rust)
├── proto/            # Protobuf definitions
├── codegen/          # Generated FFI bindings
├── flutter/          # Flutter runtime & example app
├── android/          # Android wrapper & example
├── java/             # Java desktop wrapper & TUI example
│   ├── common/
│   └── desktop/
├── dotnet/           # .NET wrapper (WinForms, client, TUI)
│   ├── src/
│   └── examples/
├── go/               # Go TUI host & client API
│   ├── pkg/
│   └── examples/
├── web/              # Browser package and demo
│   ├── js/           # JS/TS npm package and package-local WASM output
│   └── example/      # Vite browser demo and release-demo source
├── adapters/         # Compatibility layers
│   ├── aggrid/       # AG Grid API adapter (npm)
│   ├── bubbletea/    # Bubble Tea component for Go TUIs
│   ├── report/       # Report adapter
│   ├── sfdatagrid/   # SfDataGrid comparison tests
│   ├── sheet/        # Sheet API adapter (npm)
│   ├── vsflexgrid/   # ActiveX control (Windows)
│   └── xtragrid/     # XtraGrid adapter
├── rust/gtk/         # GTK4 library-host visual test harness (Rust)
├── cpp/              # Header-only C++ binding around the FFI
├── smoke-test/       # CLI smoke test
├── docker/           # Reproducible packaging
├── scripts/          # Build and utility scripts
├── dist/             # Packaged distribution artifacts
├── public/           # Static assets
└── testdata/         # Test fixture data
```

## Testing

Use the smallest loop that proves your change works.

- **Unit tests** — `make test` runs the Rust unit tests in the workspace.
- **Smoke test** — `make run` verifies the native library works end-to-end from a Rust host.
- **GTK harness** — `make rust-gtk-run` visually verifies the native FFI path on Linux.
- **Flutter** — `make flutter-run` against a connected device or emulator.
- **Web** — `make web` boots the Vite demo.
- **Terminal hosts** — `make go-tui-run`, `make dotnet-tui-run`, `make java-tui-run`.

Adapter tests (including visual comparisons against the original third-party APIs) live alongside each adapter under `adapters/`.

## Releases & CI/CD

> Full step-by-step release runbook, credential setup, and troubleshooting: **[docs/RELEASING.md](docs/RELEASING.md)**.

All build verification and GitHub Release packaging runs transparently on GitHub Actions via [`.github/workflows/build.yml`](.github/workflows/build.yml) and [`scripts/release.py`](scripts/release.py):

- **Pushes to `main`**: Run the full test suite and cross-compile all platform packages inside pinned Docker containers (`Dockerfile.android`, `Dockerfile.desktop`, `Dockerfile.ios`, `Dockerfile.web`), then update the rolling `nightly` GitHub pre-release with all 47 verified assets and `SHA256SUMS` (no external registry pushes).
- **Pre-release tags (`vX.Y.Z-rc.N`, `-alpha.N`, `-beta.N`, `-dev.N`)**: Run all verification and artifact builds and publish only to GitHub Releases as a pre-release.
- **Stable tags (`vX.Y.Z`) & staged releases (`make stage_release`)**:
  - Verify version parity (`VERSION`, Cargo workspace/lockfiles, npm packages, `flutter/pubspec.yaml`, Go `adapters/bubbletea/go.mod`, `Package.swift`, `README.md`, `CHANGELOG.md`, `flutter/CHANGELOG.md`), build and deep-verify all artifacts:
    - **Maven (`io.github.ivere27`)**: `volvoxgrid-android`, `volvoxgrid-android-lite`, `volvoxgrid-android-compose`, `volvoxgrid-android-compose-lite`, `volvoxgrid-desktop`, `volvoxgrid-desktop-lite` (`.aar`/`.jar`, `.pom`, `-sources.jar`, `-javadoc.jar`).
    - **NuGet**: `VolvoxGrid.DotNet` and `VolvoxGrid.DotNet.Lite` `.nupkg` (all 6 native RIDs: `win-x64`, `win-x86`, `linux-x64`, `linux-arm64`, `osx-x64`, `osx-arm64`).
    - **Windows / Desktop**: `volvoxgrid-activex-<ver>.zip` and `volvoxgrid-dotnet-winforms[-lite]-<ver>-{x64,x86}.zip`.
    - **Apple / SwiftPM**: `VolvoxGrid.xcframework.zip` and `VolvoxGridLite.xcframework.zip`.
    - **Web / npm**: `volvoxgrid-web[-lite]-<ver>.zip`, `volvoxgrid-demo-<ver>.zip`, and verified npm tarballs (`volvoxgrid-<ver>.tgz`, `volvoxgrid-lite-<ver>.tgz`, `volvoxgrid-ag-grid-<ver>.tgz`, `volvoxgrid-sheet-<ver>.tgz`).
    - **Debug symbols**: all 7 `*-<ver>-debug-symbols.zip` archives plus `SHA256SUMS`.
  - **No signing keys or external registry credentials live on GitHub.** Once GitHub Actions finishes building and checksum-verifying the GitHub Release, all downstream registries (Maven Central, npm, NuGet, Flutter/pub.dev, Go modules, GitHub Pages) are signed and published **locally** from the verified GitHub Release assets.

### Recommended Release Flow (100% GitHub-built, including SwiftPM `Package.swift` checksums)

Because Swift Package Manager consumers read `Package.swift` at tag `vX.Y.Z` (which embeds the SHA-256 checksums of `VolvoxGrid.xcframework.zip` and `VolvoxGridLite.xcframework.zip`), stage the release on GitHub Actions first, sync the CI-built XCFramework checksums into `Package.swift`, and then push tag `vX.Y.Z`:

```bash
# 1. Bump version across all manifests & changelogs, run local release unit tests, and push to main:
make bump-version NEW_VERSION=X.Y.Z
make check_versions test_release
git commit -am "X.Y.Z"
git push origin main

# 2. Trigger GitHub Actions to build all platform artifacts and stage Draft Release vX.Y.Z:
make stage_release

# 3. Once the GitHub Actions workflow completes, pull the verified XCFramework SHA-256
#    checksums from Draft Release vX.Y.Z into Package.swift, commit, and tag vX.Y.Z:
make sync_swift_checksums TAG=vX.Y.Z
git commit -m "Package.swift vX.Y.Z" Package.swift
git tag -a vX.Y.Z -m vX.Y.Z
git push origin main && git push origin vX.Y.Z
```

When `vX.Y.Z` is pushed after a `Package.swift`-only commit, `check-draft` (`scripts/release.py check-reusable-draft`) cryptographically verifies that only `Package.swift` changed since the draft build and that every draft asset's GitHub SHA-256 digest matches `SHA256SUMS` and `Package.swift`, then promotes the Draft GitHub Release directly to **Published** without rebuilding or mutating the XCFramework ZIP hashes.

### Local Signing & Publishing from a Published GitHub Release

After `vX.Y.Z` is published on GitHub Releases, sign and publish each package locally (no local Docker build required):

```bash
# 1. Maven Central (downloads 24 Maven files + SHA256SUMS, verifies digests/POMs/natives,
#    signs with your local GPG keyring, uploads one atomic bundle via .maven-settings.xml,
#    and polls Sonatype Central Portal until PUBLISHED):
make publish_maven_release TAG=vX.Y.Z DRY_RUN=1
make publish_maven_release TAG=vX.Y.Z

# 2. npm (downloads 4 verified .tgz tarballs + SHA256SUMS from GitHub Release vX.Y.Z,
#    checks npm registry sha512 integrity, and publishes volvoxgrid, volvoxgrid-lite,
#    @volvoxgrid/ag-grid, and @volvoxgrid/sheet):
make publish_npm_release TAG=vX.Y.Z DRY_RUN=1
make publish_npm_release TAG=vX.Y.Z

# 3. NuGet (downloads VolvoxGrid.DotNet + VolvoxGrid.DotNet.Lite .nupkg + SHA256SUMS,
#    verifies all 6 native RIDs, optionally signs with NUGET_CERT_PATH, and pushes to nuget.org):
make publish_nuget_release TAG=vX.Y.Z DRY_RUN=1
make publish_nuget_release TAG=vX.Y.Z

# 4. Go modules (tag & push go/vX.Y.Z first, then adapters/bubbletea/vX.Y.Z; see go/PUBLISHING.md):
make publish_go CONFIRM_PUBLISH_GO=1
make publish_go_bubbletea CONFIRM_PUBLISH_GO=1

# 5. Flutter / pub.dev (exports a clean git archive of flutter/ at TAG=vX.Y.Z, verifies that
#    GitHub Release XCFrameworks and Maven Central AAR/JARs are live, then runs flutter pub publish):
make publish_flutter_release TAG=vX.Y.Z DRY_RUN=1
make publish_flutter_release TAG=vX.Y.Z

# 6. GitHub Pages release demo (deploys volvoxgrid-demo-X.Y.Z.zip from the GitHub Release):
make publish_pages TAG=vX.Y.Z

# Or run Maven + npm + NuGet + Flutter + Pages sequentially:
make publish_release TAG=vX.Y.Z DRY_RUN=1
make publish_release TAG=vX.Y.Z
```

Useful environment variables and Make overrides for local signing & publishing:
- **Maven**: `.maven-settings.xml` (`<server><id>central</id>`) or `SONATYPE_USERNAME`/`SONATYPE_PASSWORD`, `MAVEN_SERVER_ID=central`, `MAVEN_GPG_KEY=<key-id>`, `MAVEN_GPG_PASSPHRASE` (prefer standard `gpg-agent` caching so pinentry prompts once across all 24 signatures).
- **npm**: `NPM_OTP=<6-digit-code>` (or interactive `npm publish` prompt), `NPM_TAG=latest`.
- **NuGet**: `NUGET_API_KEY` (or `~/.nuget-env`), optional local package signing via `NUGET_CERT_PATH=/path/to/cert.pfx`, `NUGET_CERT_PASSWORD`, and `NUGET_TIMESTAMPER=http://timestamp.digicert.com`.
- **Backport releases**: By default `release-ci` rejects tags older than the highest published stable release. Set the GitHub Repository Variable `VOLVOXGRID_ALLOW_OLDER_RELEASE=1` (or pass `--allow-older`) for intentional maintenance backports on an older series.

## Questions

- Open a GitHub Issue for bugs or feature requests.
- Open a GitHub Discussion for general questions or design conversations.

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
