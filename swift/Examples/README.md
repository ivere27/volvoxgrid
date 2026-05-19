# VolvoxGrid Swift Examples

This directory contains three single-file SwiftUI demo apps. Each one creates a `VolvoxGridClient`, loads data into the engine, and renders the grid with `VolvoxGridView`.

The same files can be used in iOS and macOS SwiftUI app projects.

| Example | File | What it shows |
|---|---|---|
| Sales | `SalesExampleApp.swift` | Sales data, subtotal rows, currency columns, progress cells, and a status dropdown. |
| Hierarchy | `HierarchyExampleApp.swift` | File-tree style outline with expand/collapse indicators and folder styling. |
| Stress | `StressExampleApp.swift` | A one-million-row dataset for rendering, scrolling, and memory testing. |

## Setup

1. Create a SwiftUI app in Xcode.
2. Add the Swift package `https://github.com/ivere27/volvoxgrid`.
3. Select the `VolvoxGrid` product for your app target.
4. Replace the generated `App.swift` with one of the example files.
5. Build and run.

The examples are not separate SwiftPM executable targets. They are app entry points meant to be copied into an iOS or macOS app target.

## Notes

- `SalesExampleApp.swift` demonstrates custom columns, styles, subtotal rows, and a dropdown editor.
- `HierarchyExampleApp.swift` demonstrates outline levels, row indicators, and styled tree rows.
- `StressExampleApp.swift` demonstrates `loadDemo("stress")` for a large generated dataset.

For the full Swift API guide, see [../README.md](../README.md).
