# VolvoxGrid Desktop (Java/Swing)

Desktop Java shell for VolvoxGrid with a CPU render path.

## Status

- CPU path: implemented (`BufferReady` + `FrameDone`)
- GPU path: stub only (explicitly unsupported for now)
- Runtime dependency: `synurang-desktop` Java runtime is expected at runtime

## Why reflection bridge?

This module uses reflection to bind to `io.github.ivere27.synurang.PluginHost` at runtime.
That allows development before the desktop runtime artifact coordinates are finalized.

## Run demo

```bash
cd /path/to/volvoxgrid
./android/gradlew -p java/desktop run
```

`run` now starts the Android-style desktop example with:
- demo switching (`sales`, `hierarchy`, `stress`)
- sort ascending/descending
- debug overlay toggle
- GPU toggle (stub; falls back to CPU)

Plugin path resolution order:
- first arg
- `VOLVOXGRID_PLUGIN_PATH`
- auto-detect under `target/debug` or `target/release`
  (`libvolvoxgrid_plugin.so` / `libvolvoxgrid_plugin.dylib` / `volvoxgrid_plugin.dll`)

Run the older minimal demo with:

```bash
./android/gradlew -p java/desktop runSimpleDemo
```

By default the build uses Maven artifacts:
- `io.github.ivere27:synurang-desktop:0.5.2`
- `io.github.ivere27:synurang-desktop-grpc:0.5.2`

The build checks `mavenLocal()` first, then Maven Central.

To force local jar mode from a directory (legacy path style):
`-PsynurangDesktopSource=local -PsynurangMavenDir=/your/path`

## Run Headless Smoke Test

```bash
cd /path/to/volvoxgrid
./android/gradlew -p java/desktop runSmoke
```

## GPU stub

`VolvoxGridDesktopPanel.setRendererBackend(RendererBackend.GPU)` currently throws `UnsupportedOperationException`.
`RendererBackend.AUTO` currently falls back to CPU.

## Main classes

- `VolvoxGridDesktopPanel`: Swing panel, render/event streams, input forwarding
- `VolvoxGridDesktopController`: high-level grid operations
- `SynurangDesktopBridge`: reflection wrapper for desktop Synurang runtime
