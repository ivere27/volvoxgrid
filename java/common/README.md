# VolvoxGrid Java Common

Shared Java contracts used by both platform shells:

- Android: `android/volvoxgrid-android`
- Desktop: `java/desktop`

Build integration:

- Android: composite build via `android/settings.gradle.kts` + dependency
  `io.github.ivere27:volvoxgrid-java-common:0.1.0-SNAPSHOT`
- Desktop: composite build via `java/desktop/settings.gradle.kts` + same dependency

Main interfaces and models:

- `io.github.ivere27.volvoxgrid.common.VolvoxGridController`
- `io.github.ivere27.volvoxgrid.common.VolvoxGridHost`
- `io.github.ivere27.volvoxgrid.common.RendererBackend`
- `io.github.ivere27.volvoxgrid.common.GridSelection`
- `io.github.ivere27.volvoxgrid.common.GridCellText`
