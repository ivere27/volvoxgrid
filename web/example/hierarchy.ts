import {
  Align,
  CellHitArea,
  CellInteraction,
  ColIndicatorCellMode,
  ColumnDataType,
  CornerIndicatorSlotKind,
  IndicatorAppearance,
  RowIndicatorSlotKind,
  SelectionMode,
  TextBaseline,
  ThemePreset,
  TreeIndicatorStyle,
  type VolvoxGrid,
  type VolvoxGridCellStyle,
  type VolvoxGridRichTextRun,
  type VolvoxGridTreeCell,
  type VolvoxGridTreeNode,
} from "../js/src/index.js";
import {
  DEFAULT_FLING_FRICTION,
  DEFAULT_FLING_IMPULSE_GAIN,
  PB_TEXT_DECODER,
  type DemoColumnSetup,
  type WasmModule,
} from "./shared.js";

export const HIERARCHY_COLS = 8;
export const HIERARCHY_ACTION_COL = 6;
export const CELL_INTERACTION_TEXT_LINK = CellInteraction.CELL_INTERACTION_TEXT_LINK;
export const CELL_HIT_AREA_TEXT = CellHitArea.HIT_TEXT;

const HIERARCHY_NAME_COL = 0;
const HIERARCHY_TYPE_COL = 1;
const HIERARCHY_SIZE_COL = 2;
const HIERARCHY_MODIFIED_COL = 3;
const HIERARCHY_PERMISSIONS_COL = 4;
const HIERARCHY_DETAILS_COL = 5;
const HIERARCHY_ICON_COL = 7;
const HIERARCHY_NAME_COL_WIDTH = 260;
const HIERARCHY_TYPE_COL_WIDTH = 80;
const HIERARCHY_SIZE_COL_WIDTH = 80;
const HIERARCHY_MODIFIED_COL_WIDTH = 120;
const HIERARCHY_PERMISSIONS_COL_WIDTH = 100;
const HIERARCHY_DETAILS_COL_WIDTH = 180;
const HIERARCHY_ACTION_COL_WIDTH = 92;
const HIERARCHY_ICON_COL_WIDTH = 24;
const HIERARCHY_TREE_COLOR = 0xFFA8A29E;
const HIERARCHY_FOLDER_TEXT_COLOR = 0xFF92400E;
const HIERARCHY_ACTION_TEXT_COLOR = 0xFF2563EB;
const HIERARCHY_OUTLINE_INDENT = 20;
const HIERARCHY_MIN_OUTLINE_INDICATOR_WIDTH = 56;
const HIERARCHY_NAME_EXPANDER_WIDTH = 280;
const HIERARCHY_HEADER_BAND_ROWS = 1;
const HIERARCHY_FOLDER_ICON = "\uE2C7";
const HIERARCHY_SHORT_DATE_FORMAT = "short date";
const MATERIAL_ICON_CHEVRON_RIGHT = "\uE5CC";
const MATERIAL_ICON_EXPAND_MORE = "\uE5CF";
const ICON_SLOT_TREE_EXPANDED = 4;
const ICON_SLOT_TREE_COLLAPSED = 5;

const HIERARCHY_COLUMN_SETUP = [
  { caption: "Name", key: "Name", width: HIERARCHY_NAME_COL_WIDTH, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined, hidden: true },
  { caption: "Type", key: "Type", width: HIERARCHY_TYPE_COL_WIDTH, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Size", key: "Size", width: HIERARCHY_SIZE_COL_WIDTH, align: Align.ALIGN_RIGHT_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Modified", key: "Modified", width: HIERARCHY_MODIFIED_COL_WIDTH, align: undefined, dataType: ColumnDataType.COLUMN_DATA_DATE, format: HIERARCHY_SHORT_DATE_FORMAT, dropdownItems: undefined, interaction: undefined },
  { caption: "Permissions", key: "Permissions", width: HIERARCHY_PERMISSIONS_COL_WIDTH, align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Details", key: "Details", width: HIERARCHY_DETAILS_COL_WIDTH, align: undefined, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined },
  { caption: "Action", key: "Action", width: HIERARCHY_ACTION_COL_WIDTH, align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: CellInteraction.CELL_INTERACTION_TEXT_LINK },
  { caption: "Icon", key: "Icon", width: HIERARCHY_ICON_COL_WIDTH, align: Align.ALIGN_CENTER_CENTER, dataType: undefined, format: undefined, dropdownItems: undefined, interaction: undefined, hidden: true },
] satisfies readonly DemoColumnSetup[];

type HierarchyRichTextRunStyle = {
  foreground?: string | number;
  color?: string | number;
  fg?: string | number;
  family?: string;
  families?: string[];
  size?: number;
  bold?: boolean;
  italic?: boolean;
  underline?: boolean;
  strikethrough?: boolean;
  strike?: boolean;
  stretch?: number;
  baseline?: string | number;
  linkUrl?: string;
  link_url?: string;
  href?: string;
  font?: HierarchyRichTextRunStyle;
};

type HierarchyRichTextRun = HierarchyRichTextRunStyle & {
  start?: number;
  startIndex?: number;
  start_index?: number;
  style?: HierarchyRichTextRunStyle;
};

type HierarchyRichTextCell = {
  text?: string;
  value?: string;
  richText?: HierarchyRichTextRun[] | { runs?: HierarchyRichTextRun[] };
  rich_text?: HierarchyRichTextRun[] | { runs?: HierarchyRichTextRun[] };
};

type HierarchyDemoRow = {
  Id: string;
  ParentId: string | null;
  Name: string;
  Type: string;
  Size: string;
  Modified: string;
  Permissions: string;
  Details?: string | HierarchyRichTextCell | null;
  Action: string;
};

function hierarchyRowDepths(rows: ReadonlyArray<HierarchyDemoRow>): number[] {
  const rowsById = new Map(rows.map((row) => [row.Id, row]));
  const depthCache = new Map<string, number>();
  const depthFor = (row: HierarchyDemoRow, visiting: Set<string>): number => {
    const cached = depthCache.get(row.Id);
    if (cached !== undefined) {
      return cached;
    }
    if (visiting.has(row.Id)) {
      throw new Error(`hierarchy demo data contains a parent cycle at ${row.Id}`);
    }
    visiting.add(row.Id);
    const parentId = row.ParentId?.trim() ?? "";
    let depth = 0;
    if (parentId !== "") {
      const parent = rowsById.get(parentId);
      if (!parent) {
        throw new Error(`hierarchy demo data references missing parent ${parentId}`);
      }
      depth = depthFor(parent, visiting) + 1;
    }
    visiting.delete(row.Id);
    depthCache.set(row.Id, depth);
    return depth;
  };
  return rows.map((row) => depthFor(row, new Set<string>()));
}

function parseArgb(value: string | number | undefined): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value >>> 0;
  }
  if (typeof value !== "string") {
    return undefined;
  }
  const raw = value.trim();
  if (raw === "") {
    return undefined;
  }
  const hex = raw.replace(/^#|^0x/i, "");
  if (/^[0-9a-fA-F]{6}$/.test(hex)) {
    return (0xFF000000 | Number.parseInt(hex, 16)) >>> 0;
  }
  if (/^[0-9a-fA-F]{8}$/.test(hex)) {
    return Number.parseInt(hex, 16) >>> 0;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed >>> 0 : undefined;
}

function parseTextBaseline(value: string | number | undefined): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value !== "string") {
    return undefined;
  }
  switch (value.trim().toLowerCase()) {
    case "normal":
      return TextBaseline.TEXT_BASELINE_NORMAL;
    case "superscript":
    case "super":
      return TextBaseline.TEXT_BASELINE_SUPERSCRIPT;
    case "subscript":
    case "sub":
      return TextBaseline.TEXT_BASELINE_SUBSCRIPT;
    default:
      return undefined;
  }
}

function buildRichTextRun(run: HierarchyRichTextRun): VolvoxGridRichTextRun | null {
  const start = run.start ?? run.startIndex ?? run.start_index;
  if (start == null || !Number.isFinite(start) || start < 0) {
    return null;
  }
  const style = run.style ?? run;
  const fontSource = style.font ?? style;
  const family = fontSource.family;
  const families = fontSource.families;
  const size = fontSource.size;
  const bold = fontSource.bold;
  const italic = fontSource.italic;
  const underline = fontSource.underline;
  const strikethrough = fontSource.strikethrough ?? fontSource.strike;
  const stretch = fontSource.stretch;
  const hasFont = family != null
    || (families != null && families.length > 0)
    || size != null
    || bold != null
    || italic != null
    || underline != null
    || strikethrough != null
    || stretch != null;

  const out: VolvoxGridRichTextRun = { startIndex: Math.trunc(start) };
  const foreground = parseArgb(style.foreground ?? style.color ?? style.fg);
  if (foreground != null) {
    out.foreground = foreground;
  }
  if (hasFont) {
    out.font = {
      family,
      families,
      size,
      bold,
      italic,
      underline,
      strikethrough,
      stretch,
    };
  }
  const baseline = parseTextBaseline(style.baseline);
  if (baseline != null) {
    out.baseline = baseline;
  }
  const linkUrl = style.linkUrl ?? style.link_url ?? style.href;
  if (linkUrl != null && linkUrl !== "") {
    out.linkUrl = linkUrl;
  }
  return out;
}

function hierarchyRichTextRuns(
  richText: HierarchyRichTextCell["richText"] | HierarchyRichTextCell["rich_text"],
): HierarchyRichTextRun[] {
  if (Array.isArray(richText)) {
    return richText;
  }
  return richText?.runs ?? [];
}

function hierarchyDetailsCell(details: HierarchyDemoRow["Details"]): {
  text: string;
  richText?: VolvoxGridRichTextRun[];
} {
  if (typeof details === "string") {
    return { text: details };
  }
  if (details == null) {
    return { text: "" };
  }
  const text = details.text ?? details.value ?? "";
  const runs = hierarchyRichTextRuns(details.richText ?? details.rich_text);
  const builtRuns = runs
    .map(buildRichTextRun)
    .filter((run): run is VolvoxGridRichTextRun => run != null);
  if (text === "" || builtRuns.length === 0) {
    return { text };
  }
  return { text, richText: builtRuns };
}

function buildHierarchyTreeNode(
  row: HierarchyDemoRow,
  hasChildren: boolean,
): VolvoxGridTreeNode {
  const details = hierarchyDetailsCell(row.Details);
  const folderStyle: VolvoxGridCellStyle | undefined =
    row.Type === "Folder" ? { foreground: HIERARCHY_FOLDER_TEXT_COLOR } : undefined;
  const actionStyle: VolvoxGridCellStyle = { foreground: HIERARCHY_ACTION_TEXT_COLOR };
  const cells: VolvoxGridTreeCell[] = [
    { col: HIERARCHY_NAME_COL, text: row.Name },
    { col: HIERARCHY_TYPE_COL, text: row.Type, style: folderStyle },
    { col: HIERARCHY_SIZE_COL, text: row.Size },
    { col: HIERARCHY_MODIFIED_COL, text: row.Modified },
    { col: HIERARCHY_PERMISSIONS_COL, text: row.Permissions },
    {
      col: HIERARCHY_DETAILS_COL,
      text: details.text,
      richText: details.richText,
    },
    { col: HIERARCHY_ACTION_COL, text: row.Action, style: actionStyle },
    { col: HIERARCHY_ICON_COL, text: row.Type === "Folder" ? HIERARCHY_FOLDER_ICON : "" },
  ];
  return {
    id: row.Id,
    parentId: row.ParentId != null && row.ParentId !== "" ? row.ParentId : undefined,
    hasChildren,
    cells,
  };
}

function buildHierarchyTreeNodes(rows: ReadonlyArray<HierarchyDemoRow>): VolvoxGridTreeNode[] {
  const parentIds = new Set(rows.map((row) => row.ParentId).filter((id): id is string => !!id));
  return rows.map((row) => buildHierarchyTreeNode(row, parentIds.has(row.Id)));
}

function hierarchyOutlineWidth(maxOutlineDepth: number): number {
  const buttonCount = Math.max(1, maxOutlineDepth + 1);
  return Math.max(HIERARCHY_MIN_OUTLINE_INDICATOR_WIDTH, buttonCount * HIERARCHY_OUTLINE_INDENT);
}

function hierarchyExpanderWidth(maxOutlineDepth: number): number {
  return hierarchyOutlineWidth(maxOutlineDepth) + HIERARCHY_NAME_EXPANDER_WIDTH;
}

function applyHierarchyIconTheme(wasmModule: WasmModule, id: number): void {
  const patchFontNames = (wasmModule as any).patch_icon_theme_default_font_names as
    | ((gridId: number, fontNames: string[]) => void)
    | undefined;
  let patchedFontFamily = false;
  if (typeof patchFontNames === "function") {
    patchFontNames(id, ["Material Icons", "MaterialIcons"]);
    patchedFontFamily = true;
  }

  const patchTextStyle = (wasmModule as any).patch_icon_theme_default_text_style as
    | ((gridId: number, fontName?: string | null, fontSize?: number | null, bold?: boolean | null, italic?: boolean | null, color?: number | null) => void)
    | undefined;
  if (!patchedFontFamily && typeof patchTextStyle === "function") {
    patchTextStyle(id, "Material Icons", null, null, null, null);
  }

  const setIconSlot = (wasmModule as any).set_icon_theme_slot as
    | ((gridId: number, slot: number, icon: string) => void)
    | undefined;
  if (typeof setIconSlot === "function") {
    setIconSlot(id, ICON_SLOT_TREE_EXPANDED, MATERIAL_ICON_EXPAND_MORE);
    setIconSlot(id, ICON_SLOT_TREE_COLLAPSED, MATERIAL_ICON_CHEVRON_RIGHT);
  }
}

function applyHierarchyConfig(grid: VolvoxGrid, maxOutlineDepth: number, maxOutlineLevel: number): void {
  const outlineWidth = hierarchyOutlineWidth(maxOutlineDepth);
  const expanderWidth = hierarchyExpanderWidth(maxOutlineDepth);

  grid.themePreset = ThemePreset.THEME_AMBER;
  grid.setOutlineConfig({
    treeIndicator: TreeIndicatorStyle.TREE_INDICATOR_ARROWS_LEAF,
    treeColor: HIERARCHY_TREE_COLOR,
    indicatorIndent: HIERARCHY_OUTLINE_INDENT,
    maxLevels: Math.max(0, maxOutlineLevel),
    showLevelButtons: true,
    labelColumn: HIERARCHY_NAME_COL,
    iconColumn: HIERARCHY_ICON_COL,
  });
  grid.setResizePolicy({ columns: true, rows: false });
  grid.setFreezePolicy({ columns: true, rows: true });
  grid.setHeaderFeatures({ sort: false, reorder: false, chooser: false });
  grid.setAutoSizeMouse(true);
  grid.setColumnIndicatorTopConfig({
    visible: true,
    bandRows: HIERARCHY_HEADER_BAND_ROWS,
    cellModes: [ColIndicatorCellMode.COL_INDICATOR_CELL_HEADER_TEXT],
    allowResize: true,
  });
  grid.setRowIndicatorStartConfig({
    visible: true,
    width: expanderWidth,
    autoSize: false,
    allowResize: true,
    slots: [{
      kind: RowIndicatorSlotKind.ROW_INDICATOR_SLOT_EXPANDER,
      width: expanderWidth,
      visible: true,
    }],
  });
  grid.setCornerIndicatorTopStartConfig({
    visible: true,
    slots: [{
      kind: CornerIndicatorSlotKind.CORNER_SLOT_OUTLINE_LEVELS,
      width: outlineWidth,
      visible: true,
    }],
  });
  grid.setIndicatorAppearance(IndicatorAppearance.INDICATOR_APPEARANCE_MODERN);
}

export function autoSizeHierarchyColumns(grid: VolvoxGrid, wasmModule: WasmModule, id: number): void {
  const autoSizeGrid = (wasmModule as any).volvox_grid_auto_size as
    | ((gridId: bigint, colFrom: number, colTo: number, equal: boolean, maxWidth: number) => Uint8Array)
    | undefined;
  if (typeof autoSizeGrid === "function") {
    autoSizeGrid(BigInt(id), 0, HIERARCHY_COLS - 1, false, 0);
    if (grid.id === id) {
      grid.invalidate();
    }
    return;
  }

  const prevId = grid.id;
  if (id !== prevId) {
    grid.useGrid(id);
  }

  try {
    grid.autoSize(0, HIERARCHY_COLS - 1);
    grid.invalidate();
  } finally {
    if (id !== prevId) {
      grid.useGrid(prevId);
    }
  }
}

export function setupHierarchyJsonDemo(grid: VolvoxGrid, wasmModule: WasmModule, id: number): void {
  const prevId = grid.id;
  if (id !== prevId) {
    grid.useGrid(id);
  }

  try {
    const rawHierarchy = grid.getDemoData("hierarchy");
    if (rawHierarchy.length === 0) {
      throw new Error("embedded hierarchy demo data is empty");
    }
    const rawRows = JSON.parse(PB_TEXT_DECODER.decode(rawHierarchy)) as HierarchyDemoRow[];
    const outlineLevels = hierarchyRowDepths(rawRows);
    const minOutlineLevel = 0;
    const maxOutlineLevel = outlineLevels.reduce((maxLevel, level) => Math.max(maxLevel, level), 0);
    const maxOutlineDepth = Math.max(0, maxOutlineLevel - minOutlineLevel);
    grid.colCount = HIERARCHY_COLS;
    grid.defineColumns(HIERARCHY_COLUMN_SETUP);
    grid.loadTree(buildHierarchyTreeNodes(rawRows));
    applyHierarchyConfig(grid, maxOutlineDepth, maxOutlineLevel);
    applyHierarchyIconTheme(wasmModule, id);

    grid.selectionMode = SelectionMode.SELECTION_FREE;
    grid.setHeaderFeatures({ sort: false, reorder: false, chooser: false });
    grid.flingImpulseGain = DEFAULT_FLING_IMPULSE_GAIN;
    grid.flingFriction = DEFAULT_FLING_FRICTION;
    grid.editable = false;
    grid.invalidate();
  } finally {
    if (id !== prevId) {
      grid.useGrid(prevId);
    }
  }
}
