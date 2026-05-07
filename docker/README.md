# Docker Release Builds

The Docker build scripts produce release artifacts for:
- Android AAR (`arm64-v8a`, `armeabi-v7a`)
- Flutter Android jniLibs (`arm64-v8a`, `armeabi-v7a`)
- Flutter Linux x64 `libvolvoxgrid.so`
- WASM packages (`wasm-pack`, target `web`)
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

Artifacts are written to:

```text
dist/docker/gpu/
dist/docker/cpu/
dist/wasm/
dist/wasm-lite/
dist/web/
```

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
