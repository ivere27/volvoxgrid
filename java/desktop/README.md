# VolvoxGrid for Java desktop (Swing)

Java/Swing bindings for the VolvoxGrid native engine. Renders into a
`JComponent` through CPU buffers or native-surface GPU rendering via JNA-loaded shared libraries
(`libvolvoxgrid.{so,dylib}` / `volvoxgrid.dll`).

## Install

The desktop binding is published as a fat JAR with platform-specific
native libraries embedded under `native/<platform>/`:

```xml
<dependency>
    <groupId>io.github.ivere27</groupId>
    <artifactId>volvoxgrid-desktop</artifactId>
    <version>0.8.9</version>
</dependency>
```

Gradle (Kotlin):

```kotlin
implementation("io.github.ivere27:volvoxgrid-desktop:0.8.9")
// or: implementation("io.github.ivere27:volvoxgrid-desktop-lite:0.8.9")
```

The JAR resolves the right native library at runtime — no manual
`LD_LIBRARY_PATH` / `PATH` setup required.

**Requirements:** Java 8+, Swing.

### Lite Variant

`volvoxgrid-desktop-lite` uses a native runtime built without the built-in Rust text engine, GPU renderer, regex search, or rayon parallelism. The Swing wrapper registers a Java2D text renderer automatically when the loaded native library has no built-in text engine.

The engine/runtime still owns the external text mask cache. Java2D only measures and rasterizes on cache misses, with a small Java-side `Font` object cache. See [../../TEXT_RENDERING.md](../../TEXT_RENDERING.md).

Local sample selection:

```bash
make java-desktop-run VOLVOXGRID_SOURCE=maven VOLVOXGRID_VARIANT=lite VOLVOXGRID_VERSION=0.8.9
make java-desktop-run-release VOLVOXGRID_VARIANT=lite
```

## Quick start

The fastest path is `VolvoxGridTableModelAdapter<T>` — a typed, data-first
adapter modeled after Swing's `TableModel` idiom. Pass typed columns and a
row list; the adapter pushes captions and cell text into the engine and
delivers commits via `setOnCellEdit(...)`.

```java
import io.github.ivere27.volvoxgrid.desktop.*;
import io.github.ivere27.volvoxgrid.desktop.VolvoxGridTableModelAdapter.*;
import javax.swing.*;
import java.util.*;

public class App {
    record Product(String name, double price, int qty) {}

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            var frame = new JFrame("VolvoxGrid");
            var panel = new VolvoxGridDesktopPanel();
            panel.initialize(NativeLibraryPathResolver.resolve(), 100, 5);

            var products = new ArrayList<>(List.of(
                new Product("Widget A", 29.99, 150),
                new Product("Widget B", 19.50, 80)
            ));

            var adapter = new VolvoxGridTableModelAdapter<>(panel, List.of(
                VolvoxGridTableModelAdapter.column  ("name",  "Name",  Product::name),
                VolvoxGridTableModelAdapter.editable("price", "Price",
                    p -> String.format("%.2f", p.price())),
                VolvoxGridTableModelAdapter.column  ("qty",   "Qty",
                    p -> Integer.toString(p.qty()))
            ));
            adapter.setOnCellEdit(edit -> {
                // edit.getRow() is the typed Product
                var p = edit.getRow();
                try {
                    products.set(edit.getRowIndex(), new Product(
                        p.name(),
                        Double.parseDouble(edit.getNewText()),
                        p.qty()
                    ));
                } catch (NumberFormatException ignore) { }
            });
            adapter.setRows(products);

            frame.setContentPane(panel);
            frame.setSize(800, 600);
            frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
            frame.setVisible(true);
        });
    }
}
```

`VolvoxColumn` factory helpers:

| Factory | Purpose |
|---|---|
| `column(field, header, value)` | Read-only column |
| `editable(field, header, value)` | Editable column (commit surfaces via `OnCellEdit`) |

`VolvoxCellEdit<T>` exposes `getRowIndex()`, `getRow()`, `getColumnIndex()`,
`getField()`, `getOldText()`, `getNewText()`.

Pass a new list to `setRows(...)` to refresh; mutating in place will not
trigger a reload.

## Low-level: `VolvoxGridDesktopPanel` + `VolvoxGridDesktopController`

For full control over the engine — partial cell updates, custom dropdown
sources, programmatic sort, merged cells — drop down to the controller form.
This is what `VolvoxGridTableModelAdapter` itself uses internally.

```java
var panel = new VolvoxGridDesktopPanel();
panel.initialize(NativeLibraryPathResolver.resolve(), 100, 5);

var ctrl = panel.createController();
ctrl.setColumnCaption(0, "Name");
ctrl.setColumnCaption(1, "Price");
ctrl.setCellText(0, 0, "Widget A");
ctrl.setCellText(0, 1, "29.99");
```

Renderer mode helpers include CPU, auto GPU, and explicit GPU backends:

```java
ctrl.setRendererModeCpu();
ctrl.setRendererModeGpu();
ctrl.setRendererModeGpuVulkan();
ctrl.setRendererModeGpuGles();
ctrl.setRendererModeGpuOpenGl();
ctrl.setRendererModeGpuDx12();
ctrl.setRendererModeGpuMetal();
```

GPU rendering uses a real native surface. The full native library enables it when the platform and driver support the selected `wgpu` backend. The lite native library is CPU-only, so GPU modes are rejected by capability checks.

See the runnable demos in this directory for fuller examples:

- `VolvoxGridDesktopExample.java` — basic panel + controller
- `VolvoxGridDesktopDemo.java`, `SalesJsonDesktopDemo.java`,
  `HierarchyJsonDesktopDemo.java` — JSON-driven demos
- `VolvoxGridDesktopTuiExample.java` — terminal-host integration
