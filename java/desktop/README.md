# VolvoxGrid for Java desktop (Swing) — in-source samples

Java/Swing bindings for the VolvoxGrid native engine. This page is the short tour next to the runnable demos in this directory. For the full guide — events, sorting, subtotals, lite variant, library resolution order, and everything else — head over to [../README.md](../README.md).

The binding renders into a `JComponent` through CPU buffers (or a native GPU surface in the full build) via JNA-loaded shared libraries (`libvolvoxgrid.{so,dylib}` / `volvoxgrid.dll`).

**Requirements:** Java 8+, Swing. Maven coordinates: `io.github.ivere27:volvoxgrid-desktop:0.8.9` (or `volvoxgrid-desktop-lite:0.8.9`).

## Quick start

The fastest path is `VolvoxGridTableModelAdapter<T>` — a typed, data-first adapter modeled after Swing's `TableModel` idiom. You describe columns once, hand it a row list, and edits surface through one callback.

```java
import io.github.ivere27.volvoxgrid.desktop.*;
import javax.swing.*;
import java.util.*;

public class App {
    static final class Product {
        final String name; final double price; final int qty;
        Product(String name, double price, int qty) {
            this.name = name; this.price = price; this.qty = qty;
        }
        String getName()  { return name; }
        double getPrice() { return price; }
        int    getQty()   { return qty; }
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            JFrame frame = new JFrame("VolvoxGrid");
            VolvoxGridDesktopPanel panel = new VolvoxGridDesktopPanel();
            panel.initialize(null, 100, 5); // null = auto-detect native library

            List<Product> products = new ArrayList<>(Arrays.asList(
                new Product("Widget A", 29.99, 150),
                new Product("Widget B", 19.50,  80)
            ));

            VolvoxGridTableModelAdapter<Product> adapter =
                new VolvoxGridTableModelAdapter<>(panel, Arrays.asList(
                    VolvoxGridTableModelAdapter.column  ("name",  "Name",  Product::getName),
                    VolvoxGridTableModelAdapter.editable("price", "Price",
                        p -> String.format("%.2f", p.getPrice())),
                    VolvoxGridTableModelAdapter.column  ("qty",   "Qty",
                        p -> Integer.toString(p.getQty()))
                ));
            adapter.setOnCellEdit(edit -> {
                Product p = edit.getRow();
                try {
                    products.set(edit.getRowIndex(), new Product(
                        p.getName(),
                        Double.parseDouble(edit.getNewText()),
                        p.getQty()
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

Pass a new list to `setRows(...)` to refresh — mutating in place won't trigger a reload.

## Column helpers

`VolvoxColumn` factory methods cover the two common cases.

| Factory | Purpose |
|---|---|
| `column(field, header, value)` | Read-only column |
| `editable(field, header, value)` | Editable column (commits surface via `OnCellEdit`) |

## Edit callbacks

`VolvoxCellEdit<T>` exposes:

| Method | What it returns |
|---|---|
| `getRowIndex()` | The row's index in your list |
| `getRow()` | The typed row object |
| `getColumnIndex()` | The column's index |
| `getField()` | The `field` you passed to `column(...)` or `editable(...)` |
| `getOldText()` | The text that was in the cell before the edit |
| `getNewText()` | The text the user just committed |

## When you need the controller

For partial cell updates, programmatic sorts, merged regions, custom dropdown sources, subtotals, search, export — drop down to `VolvoxGridDesktopPanel` + `VolvoxGridDesktopController`. The adapter uses the controller internally, so you can mix the two on the same panel.

The full controller API, events, and config live in [../README.md](../README.md).

## Renderer mode helpers

Pick a renderer on the controller when you want to be explicit. The full build supports native-surface GPU rendering; the lite build is CPU-only and rejects GPU modes via capability checks.

```java
ctrl.setRendererModeCpu();
ctrl.setRendererModeGpu();          // auto-pick the best GPU backend
ctrl.setRendererModeGpuVulkan();
ctrl.setRendererModeGpuGles();
ctrl.setRendererModeGpuOpenGl();
ctrl.setRendererModeGpuDx12();
ctrl.setRendererModeGpuMetal();
```

## Runnable demos in this directory

| File | What it shows |
|---|---|
| `VolvoxGridDesktopExample.java` | Basic panel + controller setup |
| `VolvoxGridDesktopDemo.java` | Broader feature tour driven by the controller |
| `SalesJsonDesktopDemo.java` | JSON-loaded sales data via `loadData` |
| `HierarchyJsonDesktopDemo.java` | JSON-loaded hierarchical data with outline/subtotal |
| `VolvoxGridDesktopTuiExample.java` | Terminal-host integration via the TUI byte-stream path |

Run any of them through the Makefile from the repo root — see [../README.md](../README.md#local-development) for the full list of `make java-desktop-run` targets.

## Lite variant

`volvoxgrid-desktop-lite` uses a native runtime built without the built-in Rust text engine, GPU renderer, regex search, or rayon parallelism. The Swing wrapper auto-registers a Java2D text renderer when the loaded native library has no built-in text engine. The Rust runtime still owns the external text mask cache; Java2D only measures and rasterizes on cache misses, with a small Java-side `Font` cache.

See [../../TEXT_RENDERING.md](../../TEXT_RENDERING.md) for the full text rendering and cache-ownership story.
