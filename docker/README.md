# Docker release builds

Docker exists in this repo for one reason: producing reproducible release artifacts. Developer machines drift — different Rust toolchains, different Android NDK versions, different JDKs, different `wasm-pack` versions. Local `make build` is fine while you're iterating, but anything that ends up on Maven Central, nuget.org, npmjs, or a GitHub release is built inside the pinned Docker image so the bytes are the same no matter who triggers the build.

This page walks you from a clean checkout to published packages.

## Quick start

The one-liner most maintainers want, run from the repo root:

```bash
make docker_all
```

That builds the full publishable package set, drops it under `dist/`, and leaves you ready to run the `publish_*` targets below.

## What `make docker_all` produces

Use this when you want to know what just landed in `dist/` after the quick start. `make docker_all` writes:

- Maven full and lite Android AARs (`arm64-v8a`, `armeabi-v7a`)
- Android Compose AAR full and lite
- Java desktop JAR full and lite
- iOS full and lite XCFrameworks
- Web package zips full and lite
- A self-contained web demo ZIP for GitHub Pages
- `.NET` full and lite WinForms native output, when invoked with `DESKTOP_BUILD_DOTNET=1`

The Maven set covers Android, Android lite, Compose, Compose lite, Java desktop, and Java desktop lite. The iOS XCFrameworks ship both the full engine and the lite cut. The web zips contain the minified bundles and a release-demo directory.

## Output layout

Reach for this section when a publish step can't find something. Everything lands under `dist/`:

```text
dist/docker/gpu/
dist/docker/cpu/
dist/maven/
dist/dotnet/
dist/ios/
dist/wasm/
dist/wasm-lite/
dist/web/
dist/symbols/
```

`dist/symbols/` only appears when debug-symbol bundles were produced; `make publish_github` will pick them up automatically.

## Per-target builds

Reach for these when you don't need the full sweep — for example, cutting a hotfix that only touches the web bundle or republishing iOS after a Xcode change.

### Android

Both AAR variants and the Compose AARs come out of the Maven pipeline. Trigger just the Maven slice through `make docker_all` and look under `dist/maven/`:

- Android AAR full and lite (`arm64-v8a`, `armeabi-v7a`)
- Android Compose AAR full and lite

### Java desktop

The Java desktop JAR full and lite are also produced by the Maven slice and land under `dist/maven/`.

### iOS

```bash
make docker_ios
make docker_ios_lite
```

These build the iOS full and lite XCFrameworks separately, useful when you only need to refresh the Apple artifacts.

### Web

```bash
make docker_web
WEB_DOCKER_TARGET=web make docker_web
WEB_DOCKER_TARGET=bundle make docker_web
```

Supported values for `WEB_DOCKER_TARGET` are `all`, `bundle`, `web`, `pages`, `sheet`, `sheet-lite`, `report`, `wasm`, `wasm-lite`, and `wasm-threaded`. The default is `all`.

`make docker_web WEB_DOCKER_TARGET=pages` builds only the GitHub Pages demo ZIP.

### Flutter native

The Flutter Android jniLibs (`arm64-v8a`, `armeabi-v7a`) and the Linux x64 `libvolvoxgrid.so` are produced as part of the same Docker run, alongside the Maven slice.

### WASM

WASM full and lite packages are built with `wasm-pack`, target `web`, and land under `dist/wasm/` and `dist/wasm-lite/`. You can drive them directly via `WEB_DOCKER_TARGET=wasm` or `WEB_DOCKER_TARGET=wasm-lite`.

## CPU vs GPU base images

Pick a base image when you want to control how fat the build image is. The GPU image carries the `wgpu` dependencies needed for full builds; the CPU image strips those and is significantly smaller, which is what you want for lite-only or web-only pipelines.

```bash
./scripts/docker_build_release.sh gpu
./scripts/docker_build_release.sh cpu
./scripts/docker_build_release.sh all
```

`all` builds both images. Artifacts for each variant land under `dist/docker/gpu/` and `dist/docker/cpu/`.

## Synurang dependency

This section matters if you've previously built against an external Synurang checkout and are wondering where it went. The Synurang Java/JNI runtime sources are vendored in `android/volvoxgrid-android` (Synurang v0.5.6). No external `../synurang` checkout and no JAR mount is required for Docker builds — the image has everything it needs from this repo.

## Publishing pipeline

Once `dist/` is populated, the `publish_*` targets push the artifacts to their respective registries. Run them from the repo root, with the appropriate credentials in your environment.

- `make publish_maven` — uploads Android, Android lite, Compose, Compose lite, Java desktop, and Java desktop lite.
- `make publish_github` — uploads release artifacts, including debug-symbol zips from `dist/symbols/` when present.
- `make publish_pages` — deploys the demo ZIP already uploaded to the matching GitHub release.
- `make publish_nuget` — publishes both `VolvoxGrid.DotNet` and `VolvoxGrid.DotNet.Lite`.
- `make publish_npm` — publishes `volvoxgrid`, `volvoxgrid-lite`, and adapter packages when their artifacts are present.

A typical release is `make docker_all` followed by `publish_maven`, `publish_github`, `publish_nuget` and `publish_npm`. Run `publish_pages` after `publish_github` completes. If `.NET` was excluded (no `DESKTOP_BUILD_DOTNET=1`), skip `make publish_nuget`.

## GitHub Pages release demo

The Pages site is deployed from `volvoxgrid-demo-VERSION.zip` attached to a
GitHub release. The ZIP contains the demo HTML, bundled JavaScript and matching
WASM; the workflow downloads and deploys it without rebuilding or committing
generated files. The root URL provides an entry index page linking to the Web,
Sheet, and Sheet Lite demos.

One-time setup: add `.github/workflows/pages.yml` to the repository's default
branch (`main`) and select **GitHub Actions** under **Settings → Pages → Source**.
Then run:

```bash
make docker_all
make publish_github
make publish_pages
```

Before `publish_github`, push the release tag to GitHub. If the build changed
`Package.swift` checksums, commit them and finalize the release tag first;
`publish_github` requires the remote tag to exist.

`docker_all` creates the XCFramework ZIPs and records their checksums. The
checksum-only commit may follow the source commit recorded in the binaries;
tag that final manifest commit without rebuilding merely to change the build
SHA. `publish_github` uploads the existing ZIPs without regenerating them or
editing `Package.swift`. Before creating or updating a release, it checks the
ZIP hashes and URLs against both the working manifest and `Package.swift` at
the remote release tag, and checks the version embedded in each archived
native library. A mismatch stops publication. Local checksum validation is
also available with `make verify_swift_package_checksums`.

The upload must finish before `publish_pages` runs. The workflow deliberately
does not trigger on release creation, because `publish_github` creates the
release before uploading its assets. Deployment progress appears in the
**Deploy release demo to Pages** Actions workflow.

The default URL is <https://ivere27.github.io/volvoxgrid/demos/web/>.
For a different repository path or custom domain, set `PAGES_BASE_PATH` when
building (for example `PAGES_BASE_PATH=/` for a site at the domain root).
The regular non-threaded WASM build is used; no custom response headers are
needed. Optional remote DOOM assets and fonts retain their existing fetch paths.

## Web and sheet release demos

The Firebase demo directories under `dist/web/demos/` load package JavaScript from jsDelivr import maps using `volvoxgrid@VERSION/dist/volvoxgrid.min.js`, adapter minified bundles, and the published `wasm/volvoxgrid_wasm.js` package path. These demos require `make publish_npm` for the matching `VERSION`. The separate Pages demo ZIP bundles its own JavaScript and WASM and can be deployed as soon as its release upload completes.

## Environment variables

Set these to override defaults — most releases need only `VOLVOXGRID_VERSION`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `IMAGE_TAG` | `volvoxgrid-build:latest` | Docker image tag used for the build container |
| `WORKSPACE_ROOT` | parent of current repo | Host path mounted into the container |
| `DIST_ROOT` | — | Container path override for the `dist/` output root |
| `WEB_DOCKER_TARGET` | `all` | Target selector for `make docker_web` |
| `VOLVOXGRID_VERSION` / `VERSION` | — | Release version used in package metadata and CDN paths |
| `WEB_SCALE` | `1.0` | Forwarded to web demo builds |
| `DESKTOP_BUILD_DOTNET` | `1` | `.NET` artifacts are included by default; set to `0` to skip |

## What's next

For the bigger picture of how the engine is structured, see [../ARCHITECTURE.md](../ARCHITECTURE.md). For what's in "full" vs "lite" and which adapters carry which features, see [../BUILD_VARIANTS.md](../BUILD_VARIANTS.md).
