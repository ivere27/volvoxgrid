# Docker Release Builds

The Docker build scripts produce release artifacts for:
- Android AAR full and lite (`arm64-v8a`, `armeabi-v7a`)
- Android Compose AAR full and lite
- Java desktop JAR full and lite
- iOS XCFramework full and lite
- Flutter Android jniLibs (`arm64-v8a`, `armeabi-v7a`)
- Flutter Linux x64 `libvolvoxgrid.so`
- `.NET` WinForms native output full and lite (`win-x64`, `win-x86`) when `.NET` packaging is enabled
- WASM packages full and lite (`wasm-pack`, target `web`)
- Web package zips, minified browser bundles, and release-demo directories

## Build + run

Full release build from repo root:

```bash
./scripts/docker_build_release.sh gpu
./scripts/docker_build_release.sh cpu
./scripts/docker_build_release.sh all
```

Web-only Docker builds can be run through the Makefile:

```bash
make docker_web
WEB_DOCKER_TARGET=web make docker_web
WEB_DOCKER_TARGET=bundle make docker_web
```

Supported web targets are `all`, `bundle`, `web`, `sheet`, `sheet-lite`, `report`, `wasm`, `wasm-lite`, and `wasm-threaded`.

iOS can be built separately as full or lite:

```bash
make docker_ios
make docker_ios_lite
```

The unified Makefile target builds the publishable package set:

```bash
make docker_all
```

`make docker_all` writes Maven full/lite artifacts under `dist/maven/`, iOS full/lite XCFrameworks under `dist/ios/`, web full/lite zips under `dist/web/`, and `.NET` full/lite WinForms outputs under `dist/dotnet/` when `DESKTOP_BUILD_DOTNET=1`.

Artifacts are written to:

```text
dist/docker/gpu/
dist/docker/cpu/
dist/maven/
dist/dotnet/
dist/ios/
dist/wasm/
dist/wasm-lite/
dist/web/
```

Publishing helpers consume these outputs:

- `make publish_maven` uploads Android, Android lite, Compose, Compose lite, Java desktop, and Java desktop lite artifacts.
- `make publish_github` uploads release artifacts, including debug-symbol zips from `dist/symbols/` when present.
- `make publish_nuget` publishes both `VolvoxGrid.DotNet` and `VolvoxGrid.DotNet.Lite`.
- `make publish_npm` publishes `volvoxgrid`, `volvoxgrid-lite`, and adapter packages when their artifacts are present.

The web and sheet release-demo targets generate small demo directories that load package JavaScript from jsDelivr import maps. They use `volvoxgrid@VERSION/dist/volvoxgrid.min.js`, adapter minified bundles, and the published `wasm/volvoxgrid_wasm.js` package path.

## Synurang dependency

Synurang Java/JNI runtime sources are vendored in
`android/volvoxgrid-android` (Synurang v0.5.0), so no external
`../synurang` checkout or JAR mount is required for Docker builds.

## Optional env vars

- `IMAGE_TAG` (default: `volvoxgrid-build:latest`)
- `WORKSPACE_ROOT` (default: parent of current repo)
- `DIST_ROOT` (container path override)
- `WEB_DOCKER_TARGET` (default: `all` for `make docker_web`)
- `VOLVOXGRID_VERSION` or `VERSION` (release version used in package and CDN paths)
- `WEB_SCALE` (default: `1.0`, forwarded to web demo builds)
