# VolvoxGrid for Java desktop (Swing)

Java/Swing bindings for the VolvoxGrid native engine. Renders directly into
a `JComponent` via JNA-loaded shared libraries
(`libvolvoxgrid.{so,dylib}` / `volvoxgrid.dll`).

## Install

The desktop binding is published as a fat JAR with platform-specific
native libraries embedded under `native/<platform>/`:

```xml
<dependency>
    <groupId>io.github.ivere27</groupId>
    <artifactId>volvoxgrid-desktop</artifactId>
    <version>0.8.7</version>
</dependency>
```

Gradle (Kotlin):

```kotlin
implementation("io.github.ivere27:volvoxgrid-desktop:0.8.7")
```

The JAR resolves the right native library at runtime — no manual
`LD_LIBRARY_PATH` / `PATH` setup required.

**Requirements:** Java 8+, Swing.

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

See the runnable demos in this directory for fuller examples:

- `VolvoxGridDesktopExample.java` — basic panel + controller
- `VolvoxGridDesktopDemo.java`, `SalesJsonDesktopDemo.java`,
  `HierarchyJsonDesktopDemo.java` — JSON-driven demos
- `VolvoxGridDesktopTuiExample.java` — terminal-host integration
