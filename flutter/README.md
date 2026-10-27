# VolvoxGrid for Flutter

A native Rust engine draws the grid into Flutter `RawImage`/`Texture`; Flutter
owns focus, touch forwarding and inline text/IME editors. This package supports
typed list binding and a lower-level controller. Linux desktop and Android are
the primary integration targets checked here.

## Quick start

```yaml
dependencies:
  volvoxgrid:
    path: ../volvoxgrid/flutter # Adjust to your checkout's flutter directory.
  # Compatible consumer dependencies:
  protobuf: ^6.0.0
  grpc: ^5.0.0
```

The changes in this checkout have **not been published**. The example uses a path
dependency on this `flutter/` directory; a private package copy also works.
Use the Flutter package and native engine from the same current revision. Build
and select the matching local native library as described below, or provide a
matching private native artifact. The package calls the current engine API
directly without version-specific capability probes or fallbacks.

Initialize once before creating a controller:

```dart
WidgetsFlutterBinding.ensureInitialized();
await initVolvoxGrid();
runApp(const MaterialApp(home: MyScreen()));
```

Handle loader errors in your application's startup error screen. Widget
initialization/reload errors are reported separately through `onError` and
`errorBuilder`.

Inside a `Scaffold`, this is an editable quantity table:

```dart
VolvoxDataGrid<Product>(
  rows: products, // immutable snapshot
  columns: [
    VolvoxColumn(field: 'name', header: 'Product', value: (p) => p.name),
    VolvoxColumn(field: 'qty', header: 'Quantity', value: (p) => '${p.qty}',
      type: VolvoxColumnType.integer, editable: true),
  ],
  validateEdit: (e) {
    final qty = int.tryParse(e.newText);
    return qty == null || qty < 0 ? 'Enter a non-negative integer.' : null;
  },
  onCellEdit: (e) => setState(() {
    products = [for (final p in products)
      p.id == e.row.id ? p.copyWith(qty: int.parse(e.newText)) : p];
  }),
)
```

`Product` and `copyWith` above are app model methods. The complete runnable
[business_grid.dart](example/lib/business_grid.dart) includes a concrete model,
quantity and exact decimal price columns, validation and error handling:

```sh
cd example
flutter run -t lib/business_grid.dart
```

Editable columns enable the engine's key/click edit trigger automatically.
Columns are read-only by default. Type inference is **not** performed by
`VolvoxDataGrid`; choose the type explicitly. The default editor is a Flutter
inline text editor. `loadData` in the lower-level API has separate inference.

## Identity, sorting and updates

Row IDs are an explicit, creation-only native option. The low-level controller
defaults to `create(rowIdsEnabled: false)`: index-based reading, sorting and
editing work without allocating identity storage. `rowIdsEnabled` reports the
choice for the current native grid and is false before creation/after destruction.
Enable IDs with `create(rowIdsEnabled: true)` when needed; there is no runtime
toggle or lazy activation. ID queries and ID-bearing writes fail when disabled,
and low-level edit events/sessions carry `rowId == 0` to mean no identity.
Destroy and recreate the grid to change this choice; its data must be loaded again.

`VolvoxDataGrid` always creates its grid with IDs enabled, including read-only
tables, because source-object binding must survive sorting. An app-supplied
controller must be uncreated or have been created with `rowIdsEnabled: true`.
An already-created ID-disabled controller produces an initialization error before
the wrapper changes its data or edit policy; it is never silently recreated.

`VolvoxColumn.field` must be unique and nonempty; it is the column identity after
header dragging. Native row IDs are **positive signed 64-bit integers**
(`1..9223372036854775807`); `0` cannot be assigned as an ID. The optional `getRowId` callback returns
an `int` that is unique within this grid. The engine stores that ID without adding
a hidden column. On Linux/Android, Dart `int` preserves the full signed 64-bit
range, including IDs above `2^53`; the wrapper never converts IDs through `double`.
Raw generated protobuf messages use `fixnum.Int64` at the wire boundary.

Usually omit `getRowId` and let the engine generate IDs. Generated IDs survive
sorting, movement and edits; deletion invalidates them and full replacement
creates fresh IDs. They are opaque and scoped to the native grid instance: do not
decode them, persist them as database keys, or reuse them after grid recreation.
Generated IDs encode an internal slot and generation; they are not random IDs,
UUIDs, business identifiers, or a guarantee of uniqueness across grids.
Use `edit.row` to access your original application object and its business key.
If the app needs stable IDs across full refreshes, supply its own unique positive
numeric IDs and keep them unchanged for the same records. Keep string SKU/UUID
keys on the model; do not convert them with a collision-prone hash or `double`.
Duplicate, zero and negative IDs are rejected before assignment.

| Edit property | Meaning |
|---|---|
| `row` | Original object from the applied source snapshot |
| `rowId` | Engine row ID: supplied by `getRowId`, or generated by the engine |
| `rowIndex` | Zero-based index in the applied `rows`, **not screen order** |
| `columnIndex` | Zero-based index in the applied `columns`, **not screen order** |
| `field` | Stable original column field |
| `displayRowIndex`, `displayColumnIndex` | Zero-based engine coordinates at edit time |

Sorting A,B to B,A and editing the first row targets B. Reordering a read-only
column and an editable column preserves both permission and field. The wrapper
uses the ID captured in the native edit event to resolve the original object,
and rejects a commit if the target changed during editing. The engine manages
identity independently of display position and includes IDs in edit events.

Pass a **new rows list** to replace, append or remove rows:

```dart
setState(() => products = [...products, incoming]);
setState(() => products = products.where((p) => p.id != deletedId).toList());
```

Same-list mutation does not refresh. For an intentionally mutable external
collection, increment `dataVersion` after a change. Fresh equivalent column
lists/closures created by `build` do not resend the table; changing a value or
`getRowId` callback's meaning also requires a new rows list or `dataVersion`.
Configuration changes (field/header/type/editor/width/editability) do reload.
Keep supplied row lists and objects immutable while an update is queued. Obsolete
queued requests are discarded before allocating their snapshot arrays.
Full replacement resets visual order/selection and cancels an in-progress edit;
it does not preserve a user's sort or dragged order. Newest queued data wins;
disposal/controller replacement stops subsequent work on the old controller.

`VolvoxDataGrid` owns its controller's schema, data and edit policy, even when
the controller was supplied by the app. Do not modify its schema/rows, reuse its
controller in another grid, or issue concurrent structural commands. Sorting and
column moving between edit sessions are supported. For frequent streaming append/partial
updates, use `VolvoxGridController` + `VolvoxGridWidget`, `insertRows`/`appendData`
and `updateCells`/`setCells`. With IDs enabled, the engine maintains them while the app owns
object mapping and validation. Low-level row/column indices refer to the engine's
current order; they are not IDs.

The low-level API can supply IDs in the same table load and query them without a
display column:

```dart
final controller = VolvoxGridController();
await controller.create(rows: 2, cols: 1, rowIdsEnabled: true);
await controller.loadTable(2, 1, [
  CellValue(text: 'Product A'),
  CellValue(text: 'Product B'),
], atomic: true, rowIds: [101, 102]);
final id = await controller.getRowId(0); // 101, as a Dart int
final position = await controller.findRowById(102); // current index, or null
final identities = await controller.getRows(startRow: 0, rowCount: 2);
// List<VolvoxRowIdentity>: each item has int index and int rowId.
```

On the wire, `CreateRequest.row_ids_enabled` defaults to false and is only read
when creating the native grid. `LoadTableRequest.row_ids` assigns IDs in input row order;
`RowDef.row_id` assigns an ID to an existing row through `DefineRows`. IDs must
be positive signed 64-bit integers and unique within one grid, including fixed rows. Invalid ID
assignments are rejected before changing the table. `GetRows` returns current
`index`/`row_id` pairs for a range or requested IDs. Missing IDs are omitted from
ID lookups. Generated IDs are opaque and scoped to the grid instance; do not
parse them or use them as database keys. Keyed high-level loads reuse
the provided IDs after native validation, without any ID query. Unkeyed
loads query generated IDs once to build their source mapping.
Content-only clears retain IDs. CSV/JSON/archive replacement imports create new
IDs; reassign application IDs when importing records that need persistent
identity. The separate tree service keeps `node_id` as its authoritative node
identity; projected grid rows receive IDs that survive collapse/expand. A nested
`TreeNode.row.row_id` does not assign that projection ID; use `DefineRows` for a
visible grid row's application ID.

With IDs enabled, a fresh dense grid's automatic-ID arrays use about 12 bytes per row before
allocator/capacity overhead. Slot-generation history is retained up to the grid's
high-water mark; deleted/free slots can therefore retain identity storage until
the grid is destroyed. Supplied IDs that differ from automatic IDs also need an
alias array and reverse lookup map. These figures cover only native identity
storage, excluding cells, Flutter source maps, protobuf buffers and snapshots.
With IDs disabled, the identity arrays remain unallocated; querying an ID does
not allocate them.

## Types, exact values and editors

| `VolvoxColumnType` | Storage and sorting |
|---|---|
| `text` (default) | Text; string sort |
| `integer` | Canonical signed integer string, numeric sort, no double conversion |
| `decimal` | Canonical signed decimal string, numeric sort, no double conversion |
| `number` | Explicit approximate IEEE-754 double; numeric sort |
| `boolean` | Validated `true`/`false` text; text sort and commit-based text editor |

Integer/decimal text excludes grouping separators and currency symbols; keep
business money in a decimal/string/minor-unit model. The wrapper does not parse
those values through `double`. Native formatting currently uses floating point,
so `format` is rejected for exact numeric columns. Use `type: number` and
`format: '#,##0.00'` only for intentionally approximate values. `width` is logical
pixels. `editor` accepts an exported `EditorSpec` for text/number/list/date editor
configuration. Exact numeric columns require text editors. Checkbox, button and
custom action editors are low-level features because they can bypass text commit
validation; the high-level wrapper rejects them.

**Native engine requirement:** use the matching current engine for row IDs,
exact ordering beyond double precision, correct typed readback after commits,
and native clipboard permission enforcement. Build/use this engine with
`VOLVOXGRID_SOURCE=local`, or select a matching private native artifact. No
release is performed by these changes. Never treat `number` as an exact money
or arbitrary-integer type.

## Validation and server persistence

`validateEdit` is **synchronous**: return null to accept or a message to reject.
Type checks run first. `onValidationError` can show that message. `onCellEdit`
reports an accepted local commit; it is not confirmation of a server save.

The wrapper protects read-only columns through edit decisions and native column
metadata. Grid-range Paste/Cut/Delete is disabled, including controller clipboard
mutations while bound, because the current bulk API has no per-cell validation
transaction. Copy and text paste/delete inside the active editor are supported;
editor text is validated on commit. Programmatic low-level writes are trusted app
operations, not a permission boundary.

The app owns asynchronous I/O, conflict detection and rollback. For example,
with immutable `Product` objects and an API accepting a server revision:

```dart
final pending = <String>{}; // State field

Future<void> save(VolvoxCellEdit<Product> edit) async {
  final id = edit.row.id; // Business key from the original source object.
  final old = products.singleWhere((p) => p.id == id);
  final optimistic = old.copyWith(qty: int.parse(edit.newText));
  pending.add(id);
  setState(() => products = [for (final p in products)
    p.id == id ? optimistic : p]);
  try {
    final saved = await api.saveProduct(optimistic, ifMatch: old.revision);
    if (!mounted) return;
    // A later refresh may already have replaced this object. Do not overwrite it.
    setState(() => products = [for (final p in products)
      identical(p, optimistic) ? saved : p]);
  } catch (error) {
    if (!mounted) return;
    setState(() => products = [for (final p in products)
      identical(p, optimistic) ? old : p]); // rollback, never use display row
    showSaveError(error); // app-specific error/retry UI
  } finally {
    pending.remove(id);
  }
}
// validateEdit: (e) => pending.contains(e.row.id) ? 'Save in progress.' : validate(e),
// onCellEdit: (e) { unawaited(save(e)); }, // import dart:async; save catches failures
```

Serialize saves per business row or use request revisions. For pessimistic saves,
keep authoritative rows unchanged until success; restore them with a new list or
`dataVersion` on failure. A failed/obsolete response must not overwrite a newer
refresh. The grid does not provide backend transactions, undo history or retries.

## Lifecycle, layout and accessibility

Use `active: selectedTab == gridTab` in retained tabs; disabled `TickerMode` also
suspends rendering, event streams and input. Offscreen placement alone is not a
pause. App-owned server requests continue independently. The wrapper disposes
only controllers it created; callers dispose their supplied controllers after
unmounting the widget. Suspension cancels an uncommitted edit.

`fontSize` (default 14) and `rowHeight` (32) are logical base dimensions, scaled
together by the system `TextScaler` and display density. Use
`followSystemTextScale: false` only if the app explicitly supplies its own scaled
sizes. Choose suitable column widths and test large accessibility font settings.
Both viewport dimensions must be finite: use `Expanded` in a bounded `Column`, or
`SizedBox(height: 320)` in a `ScrollView`. The grid scrolls its own data; it does
not provide intrinsic height or Flutter slivers. Its raw-pointer scrolling does
not participate as a Flutter `Scrollable` in a parent's gesture arena. Avoid
competing vertical scroll owners; touch down may select a cell before a drag is
recognized.

Keep `Scaffold(resizeToAvoidBottomInset: true)` and let its body shrink with the
keyboard. On viewport resize, the host calls `showCell` for the active edit cell.
A fixed overlay outside that resized layout is not automatically protected from
keyboard occlusion. Inline editors use Flutter `TextField` and retain composing
text until submission. Synthetic composition tests do not establish real Android
keyboard compatibility; composition, candidate selection, keyboard occlusion and
touch selection/scrolling still need acceptance tests on the target devices.

For the low-level controller, font and row/header dimensions are physical pixels:
multiply `MediaQuery.textScalerOf(context).scale(baseFontSize)` and the desired
logical row height by `MediaQuery.devicePixelRatioOf(context)`. Also pass
`scale: dpr` when creating the controller for native decorations. Creation-time
decoration scaling requires controller recreation if the display density changes.
The high-level wrapper updates font/layout dimensions automatically; its editor
overlay does not apply system text scaling a second time. Native text does not
inherit `Theme.textTheme`.

**Per-cell Semantics/TalkBack table navigation is not implemented.** Provide an
accessible Flutter list/detail/form alternative for users of screen readers.
An open editor exposes normal text-field semantics, which does not provide table
navigation or announcements for cell headers, values, selection and editability.
Real TalkBack traversal remains unverified.

## Native library resolution

The package works without the monorepo `VERSION`, a Gradle wrapper or prebundled
native binaries. Android resolves a Maven AAR; Linux/Windows resolve the desktop
JAR directly during CMake configuration. Downloads/extraction go into the
consumer's build directory. macOS uses the desktop JAR; iOS uses the release
XCFramework. Failure stops the build with artifact/path and recovery instructions.

Both source modes validate Flutter's requested Android ABIs and stop before
packaging if any native library is missing. For phones, use
`flutter build apk --target-platform android-arm64` (or
`--target-platform android-arm,android-arm64`). An x86_64 emulator requires a
native artifact or local build that actually includes x86_64; the default
multi-architecture Flutter target requires every requested ABI in the artifact.

Version priority is explicit environment `VOLVOXGRID_VERSION`, then build-system
`-PvolvoxgridVersion` (Gradle) / `-DVOLVOXGRID_VERSION` (CMake), then this package's
`pubspec.yaml` version (without `+build`), then immediate **recognized monorepo**
`VERSION`. An unrelated parent or consumer `VERSION` is never consulted.

| Variable | Default / purpose |
|---|---|
| `VOLVOXGRID_SOURCE` | `maven`; explicit `local` never silently downloads |
| `VOLVOXGRID_VERSION` | Package version; pin a compatible native version |
| `VOLVOXGRID_LIBRARY` | Explicit local desktop shared-library file |
| `VOLVOXGRID_VARIANT` | Full by default; `lite` on supported platforms |

`maven` never silently falls back to incidental local binaries. `local` desktop
uses the explicit library, packaged local location, or recognized repository's
`target/release` / `target/debug`; local Android needs the monorepo helper sources
and its built Android native libraries. Linux/Windows text rendering requires the
full variant. Apple/Windows changes need builds on those platforms before release.

For a source Linux build with the native fixes:

```sh
# From repository root; does not publish anything.
cargo build -p volvoxgrid-runtime --no-default-features --features standard
# In your Flutter consumer using this package:
VOLVOXGRID_SOURCE=local VOLVOXGRID_LIBRARY=/absolute/path/to/target/debug/libvolvoxgrid.so flutter run -d linux
```

Flutter 3.35.6 / Dart 3.9.2 is the verified consumer environment. The protobuf 6
constraint requires Dart 3.7+ regardless of older advertised package SDK bounds.
Linux needs the normal Flutter desktop toolchain (including GTK development
files); Android needs the Android SDK/JDK. Do not patch shared pub-cache files.

## Reproducible verification

```sh
python3 flutter/tool/test_native_resolution.py
python3 flutter/tool/verify_package_consumer.py --platform both
cd flutter
flutter test
VOLVOXGRID_TEST_LIB=/absolute/path/libvolvoxgrid.so flutter test
```

The consumer script creates a separate package-only directory and private pub
cache, resolves protobuf 6/grpc 5, and builds both targets without publication.
The native binding and live-editor tests require `VOLVOXGRID_TEST_LIB`; otherwise
they are skipped, not passed. The live-editor regression uses real native event
streams and a Flutter text editor. Widget tests also exercise synthetic Korean
composition and touch-scroll forwarding. These checks do not replace physical
Android keyboard, touch or TalkBack acceptance tests. Changes awaiting release
are recorded in [CHANGELOG.md](CHANGELOG.md).
