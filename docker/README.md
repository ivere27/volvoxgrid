# Docker Release Build

This image builds release artifacts for:
- Android AAR (`arm64-v8a`, `armeabi-v7a`)
- Flutter Android jniLibs (`arm64-v8a`, `armeabi-v7a`)
- Flutter Linux x64 `libvolvoxgrid_plugin.so`
- wasm package (`wasm-pack`, target `web`)

## Build + run

From repo root:

```bash
./scripts/docker_build_release.sh gpu
./scripts/docker_build_release.sh cpu
./scripts/docker_build_release.sh all
```

Artifacts are written to:

```text
dist/docker/gpu/
dist/docker/cpu/
```

## Synurang dependency

Synurang Java/JNI runtime sources are vendored in
`android/volvoxgrid-android` (Synurang v0.5.0), so no external
`../synurang` checkout or JAR mount is required for Docker builds.

## Optional env vars

- `IMAGE_TAG` (default: `volvoxgrid-build:latest`)
- `WORKSPACE_ROOT` (default: parent of current repo)
- `DIST_ROOT` (container path override)
