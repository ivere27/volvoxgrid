/**
 * VolvoxGrid public API.
 *
 * The library is layered:
 *
 * 1. **Facade** — the `VolvoxGrid` class and the typed `VolvoxGrid*` config
 *    interfaces, helpers, and enums re-exported below. This is the 95% path
 *    and the only path with API stability guarantees.
 *
 * 2. **Typed proto escape hatch** — `grid.ffi` returns a synurang-generated
 *    `VolvoxGridServiceFfi` client. Pass typed request messages from
 *    `volvoxgrid/generated/volvoxgrid_lite.js`. This covers every RPC in
 *    `proto/volvoxgrid.proto`.
 *
 * 3. **Raw escape hatch** — direct imports from `./generated/volvoxgrid_ffi.js`
 *    and `./generated/volvoxgrid_lite.js`, `grid.rawWasm`, and
 *    `grid.callProto(...)` for hand-encoded wasm calls.
 *
 * If you find yourself reaching for the escape hatch, that's a signal that
 * the facade is missing a typed method — please file an issue.
 */

export { VolvoxGrid, dropdownFromLabels } from "./volvoxgrid.js";
export type {
  VolvoxGridBarcode,
  VolvoxGridBarcodeCaption,
  VolvoxGridBarcodeEncoding,
  VolvoxGridBarcodeRender,
  VolvoxGridBeforeEditDetails,
  VolvoxGridBeforeSortDetails,
  VolvoxGridCellEditValidatingDetails,
  VolvoxGridCellStyle,
  VolvoxGridCellUpdate,
  VolvoxGridColumnIndicatorConfig,
  VolvoxGridCallProtoOptions,
  VolvoxGridColumnSpec,
  VolvoxGridColumnDef,
  VolvoxGridCompareCallback,
  VolvoxGridCompareDetails,
  VolvoxGridContextMenuRequest,
  VolvoxGridContextMenuTrigger,
  VolvoxGridCornerIndicatorConfig,
  VolvoxGridCornerIndicatorSlot,
  VolvoxGridDataRow,
  VolvoxGridDropdown,
  VolvoxGridDropdownItem,
  VolvoxGridEventListener,
  VolvoxGridEventMap,
  VolvoxGridGetRowId,
  VolvoxGridGetRowIdParams,
  VolvoxGridLoadTreeOptions,
  VolvoxGridOptions,
  VolvoxGridOutlineConfig,
  VolvoxGridProtoMessageType,
  VolvoxGridProtoRequest,
  VolvoxGridRichTextRun,
  VolvoxGridRowId,
  VolvoxGridRowIndicatorConfig,
  VolvoxGridRowIndicatorSlot,
  VolvoxGridRowSpec,
  VolvoxGridSelectionHoverMode,
  VolvoxGridSetDataOptions,
  VolvoxGridTransaction,
  VolvoxGridTransactionResult,
  VolvoxGridTreeCell,
  VolvoxGridTreeDataOptions,
  VolvoxGridTreeNode,
  VolvoxGridUpdateCellsOptions,
  VolvoxGridUpdateRowsOptions,
  VolvoxGridValueFormatterParams,
  VolvoxGridValueGetterParams,
  VolvoxGridEditorSessionEndedDetails,
  VolvoxGridEditorSessionStartedDetails,
  VolvoxGridEditorSessionUpdatedDetails,
  VolvoxGridValidationError,
} from "./volvoxgrid.js";
export { VolvoxGridElement } from "./volvoxgrid-element.js";
export { setupDefaultInput, setupDefaultKeyboard, setupDefaultContextMenu } from "./default-input.js";
export { createCanvas2DTextRenderer } from "./canvas2d-text-renderer.js";
export { createCanvas2DRasterizer } from "./canvas2d-rasterizer.js";
export { WasmPluginHost } from "./proto-host.js";
export type { PluginHost, PluginStream, WasmPluginHostOptions } from "./proto-host.js";
export { EventPump } from "./event-pump.js";
export type { EventPumpOptions } from "./event-pump.js";
export {
  Align,
  BarcodeCaptionPosition,
  BarcodeCheckDigitMode,
  BarcodeQrErrorCorrection,
  BarcodeSymbology,
  BarcodeTextEncoding,
  BorderStyle,
  CellHitArea,
  CellInteraction,
  ColIndicatorCellMode,
  ColumnDataType,
  CornerIndicatorSlotKind,
  EditTrigger,
  EditorUpdateReason,
  FocusBorderStyle,
  GridLineStyle,
  GroupTotalPosition,
  HeaderPolicy,
  ImageAlignment,
  IndicatorAppearance,
  LoadDataStatus,
  PresentMode,
  RenderLayerBit,
  RendererMode,
  RowIndicatorSlotKind,
  ScrollBarsMode,
  SelectionMode,
  SelectionVisibility,
  TextBaseline,
  ThemePreset,
  TreeIndicatorStyle,
} from "./generated/volvoxgrid_ffi.js";
