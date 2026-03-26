/**
 * VolvoxSheet — Main orchestrator.
 *
 * Wires together VolvoxGrid WASM, key dispatch, edit state machine,
 * selection model, data store, undo/redo, clipboard, formula bar,
 * toolbar, context menu, and the spreadsheet theme.
 */

import { VolvoxGrid } from "volvoxgrid";
import * as volvoxgrid from "volvoxgrid";
import type {
  VolvoxSheetOptions, VolvoxSheetApi, CellRef, CellRange,
  CellStyleUpdate, SpreadsheetAction, VolvoxSheetGrid,
} from "./types.js";
import { encodeGridConfig } from "./proto/config-encoder.js";
import {
  encodeUpdateCellsRequest,
  encodeEditSetText,
  encodeEditSetHighlights,
  type CellStyleFields,
  type CellUpdateEntry,
  type HighlightRegionArg,
} from "./proto/proto-utils.js";
import {
  decodeGridEventEnvelope,
  decodeCellFocusPayload,
  decodeAfterEditPayload,
  decodeCellEditChangePayload,
  decodeSelectionChangedPayload,
  EVENT_CELL_FOCUS_CHANGED,
  EVENT_ENTER_CELL,
  EVENT_SELECTION_CHANGED,
  EVENT_START_EDIT,
  EVENT_AFTER_EDIT,
  EVENT_CELL_EDIT_CHANGE,
} from "./proto/event-decoder.js";
import { buildSheetConfig, ALIGN, SHEET_COLORS } from "./theme/sheet-theme.js";
import { KeyDispatch } from "./core/key-dispatch.js";
import { EditStateMachine } from "./core/edit-state-machine.js";
import { SelectionModel } from "./core/selection-model.js";
import { DataStore } from "./core/data-store.js";
import { UndoRedoStack, CellValueChange, CellStyleChange, BatchCommand, SnapshotDataChange } from "./core/undo-redo.js";
import { ClipboardManager } from "./core/clipboard.js";
import { FormulaBar } from "./ui/formula-bar.js";
import { Toolbar, type ToolbarAction } from "./ui/toolbar.js";
import { ContextMenu, type ContextMenuAction, type ContextMenuScope } from "./ui/context-menu.js";
import { StatusBar } from "./ui/status-bar.js";
import { SheetTabs, type SheetSnapshot } from "./ui/sheet-tabs.js";
import { FindReplaceBar } from "./ui/find-replace.js";
import { FillHandle } from "./core/fill-handle.js";
import { letterToCol, toA1 } from "./core/cell-reference.js";
import "./theme/css/volvox-sheet.css";

interface DefaultFontSource {
  family: string;
  url: string;
}

const DEFAULT_LATIN_FONT: DefaultFontSource = {
  family: "Roboto",
  url: "https://cdn.jsdelivr.net/gh/googlefonts/roboto-2@main/src/hinted/Roboto-Regular.ttf",
};
const DEFAULT_CJK_FONTS = {
  ko: {
    family: "Noto Sans KR",
    url: "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/KR/NotoSansKR-Regular.otf",
  },
  ja: {
    family: "Noto Sans JP",
    url: "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/JP/NotoSansJP-Regular.otf",
  },
  zhHans: {
    family: "Noto Sans SC",
    url: "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf",
  },
  zhHant: {
    family: "Noto Sans TC",
    url: "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@main/Sans/SubsetOTF/TC/NotoSansTC-Regular.otf",
  },
} as const satisfies Record<string, DefaultFontSource>;
const SHEET_ROW_INDICATOR_MODE = 1; // numbers

const createCanvas2DTextRendererMaybe =
  (volvoxgrid as { createCanvas2DTextRenderer?: (wasm: any) => { measureText: Function; renderText: Function } })
    .createCanvas2DTextRenderer;
const createCanvas2DRasterizerMaybe =
  (volvoxgrid as { createCanvas2DRasterizer?: () => Function })
    .createCanvas2DRasterizer;

function preferredBrowserLanguages(): string[] {
  if (typeof navigator === "undefined") {
    return [];
  }
  const values: string[] = [];
  if (Array.isArray(navigator.languages)) {
    values.push(...navigator.languages);
  }
  if (typeof navigator.language === "string") {
    values.push(navigator.language);
  }
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    const normalized = value.trim().toLowerCase();
    if (!normalized || seen.has(normalized)) {
      continue;
    }
    seen.add(normalized);
    out.push(normalized);
  }
  return out;
}

function isTraditionalChinese(tag: string): boolean {
  return tag.startsWith("zh-hant")
    || tag.includes("-hant-")
    || tag.startsWith("zh-tw")
    || tag.startsWith("zh-hk")
    || tag.startsWith("zh-mo");
}

function isSimplifiedChinese(tag: string): boolean {
  return tag === "zh"
    || tag.startsWith("zh-hans")
    || tag.includes("-hans-")
    || tag.startsWith("zh-cn")
    || tag.startsWith("zh-sg");
}

function resolveDefaultFontSource(): DefaultFontSource {
  for (const language of preferredBrowserLanguages()) {
    if (language.startsWith("ko")) {
      return DEFAULT_CJK_FONTS.ko;
    }
    if (language.startsWith("ja")) {
      return DEFAULT_CJK_FONTS.ja;
    }
    if (isTraditionalChinese(language)) {
      return DEFAULT_CJK_FONTS.zhHant;
    }
    if (isSimplifiedChinese(language)) {
      return DEFAULT_CJK_FONTS.zhHans;
    }
  }
  return DEFAULT_LATIN_FONT;
}

interface FormulaRefToken {
  start: number;
  length: number;
  row1: number;
  col1: number;
  row2: number;
  col2: number;
}

export class VolvoxSheet implements VolvoxSheetApi {
  readonly grid: VolvoxSheetGrid;
  private wasm: any;
  private container: HTMLElement;
  private rootEl: HTMLDivElement;
  private canvasWrap: HTMLDivElement;
  private canvas: HTMLCanvasElement;
  private destroyed = false;

  // Core modules
  private keyDispatch: KeyDispatch;
  private editState: EditStateMachine;
  private selection: SelectionModel;
  private store: DataStore;
  private undoStack: UndoRedoStack;
  private clipboard: ClipboardManager;

  // UI modules
  private formulaBar: FormulaBar | null = null;
  private toolbar: Toolbar | null = null;
  private contextMenu: ContextMenu;
  private contextMenuScope: ContextMenuScope = "cell";
  private statusBar: StatusBar | null = null;
  private sheetTabs: SheetTabs | null = null;
  private findBar: FindReplaceBar | null = null;
  private fillHandle: FillHandle | null = null;

  // VolvoxGrid's edit input element (on document.body)
  private gridEditInput: HTMLInputElement | null = null;

  // Per-cell alignment cache (grid coordinates → ALIGN value)
  private cellAlignments = new Map<string, number>();
  private cellStyleCache = new Map<string, CellStyleFields>();

  // Cells that were auto-aligned (numeric detection) — manual alignment overrides
  private autoAligned = new Set<string>();

  // Single-click edit timer (cancelled by dblclick)
  private singleClickTimer: number = 0;
  private lastClickedCell: string = "";

  // Pointer-driven selection drag state
  private _pointerDrag = false;
  private _pointerDragAnchor: CellRef | null = null;
  private _multiRangePointerDrag = false;
  private _multiRangeBaseRanges: CellRange[] = [];
  private _multiRangeAnchor: CellRef | null = null;
  private _multiRangeEnd: CellRef | null = null;
  // Active inserted formula token span while dragging a formula range pick.
  private _formulaDragRefSpan: { start: number; length: number } | null = null;

  // Pre-merge position: the row/col before the selection snapped into a merge master.
  // Used to restore the user's axis position when exiting the merge.
  private _preMergeRow: number = 0;
  private _preMergeCol: number = 0;
  private pendingEditOriginalRaw = new Map<string, string>();

  // Event loop
  private eventPollTimer: number = 0;
  private defaultFontName: string = "";
  private defaultFontSize: number = 11;
  private baseDefaultRowHeight: number = 21;
  private baseDefaultColWidth: number = 64;
  private baseColumnHeaderHeight: number = 24;
  private baseRowIndicatorStartWidth: number = 40;
  private currentColumnHeaderHeight: number = 24;
  private responsiveScale: number = 1;
  private userZoomScale: number = 1;
  private pinchBaseZoomScale: number | null = null;
  private activeTouchPointers = new Set<number>();
  private layoutPixelScale: number = 0;
  private layoutResizeObserver: ResizeObserver | null = null;
  private static readonly SHEET_FONT_SIZE_STEPS = [
    6, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72,
  ] as const;
  private static readonly MIN_ZOOM_SCALE = 0.25;
  private static readonly MAX_ZOOM_SCALE = 4.0;
  private static readonly ZOOM_SCALE_EPSILON = 0.001;
  private static readonly PINCH_SNAP_TO_ONE_EPSILON = 0.03;
  private static readonly SHEET_PT_TO_CSS_PX = 96 / 72;
  private static readonly FONT_LINE_HEIGHT_MULTIPLIER = 1.2;
  private static readonly FONT_ROW_PADDING_PX = 2;

  constructor(options: VolvoxSheetOptions) {
    this.container = options.container;
    this.wasm = options.wasm;

    // Ensure protobuf service plugin is registered (required for styles, configure, etc.)
    if (typeof this.wasm.init_v1_plugin === "function") {
      try { this.wasm.init_v1_plugin(); } catch { /* already registered */ }
    }

    // Lite WASM builds disable the built-in text engine (cosmic-text).
    // Register Canvas2D callbacks in that case so text can render.
    const hasBuiltinTextEngine = typeof this.wasm.has_builtin_text_engine === "function"
      ? Boolean(this.wasm.has_builtin_text_engine())
      : true;
    const defaultFontSource = resolveDefaultFontSource();
    const explicitFontUrl =
      typeof options.fontUrl === "string" ? options.fontUrl.trim() : "";
    const resolvedFontName =
      options.fontName ?? (hasBuiltinTextEngine ? defaultFontSource.family : "");
    if (!hasBuiltinTextEngine
      && typeof this.wasm.set_text_renderer === "function"
      && typeof createCanvas2DTextRendererMaybe === "function") {
      const textRenderer = createCanvas2DTextRendererMaybe(this.wasm);
      this.wasm.set_text_renderer(textRenderer.measureText, textRenderer.renderText);
    }
    if (hasBuiltinTextEngine
      && typeof this.wasm.set_glyph_rasterizer === "function"
      && typeof createCanvas2DRasterizerMaybe === "function") {
      this.wasm.set_glyph_rasterizer(createCanvas2DRasterizerMaybe());
    }

    // Build DOM structure
    this.rootEl = document.createElement("div");
    this.rootEl.className = "vx-sheet-root";

    this.canvas = document.createElement("canvas");
    this.canvas.tabIndex = 0;

    // Configure grid dimensions
    const sheetConfig = buildSheetConfig({
      rows: options.rows,
      cols: options.cols,
      fontName: resolvedFontName,
      fontSize: options.fontSize,
      defaultRowHeight: options.defaultRowHeight,
      defaultColWidth: options.defaultColWidth,
    });
    this.defaultFontName = sheetConfig.font?.family ?? resolvedFontName;
    this.defaultFontSize = sheetConfig.font?.size ?? 11;
    this.baseDefaultRowHeight = sheetConfig.defaultRowHeight ?? 21;
    this.baseDefaultColWidth = sheetConfig.defaultColWidth ?? 64;
    this.baseColumnHeaderHeight = Math.max(24, this.baseDefaultRowHeight);
    this.currentColumnHeaderHeight = this.toLayoutPixels(this.baseColumnHeaderHeight);

    // Create VolvoxGrid
    this.grid = new VolvoxGrid(
      this.canvas,
      this.wasm,
      sheetConfig.rows,
      sheetConfig.cols,
    ) as VolvoxSheetGrid;
    if (!hasBuiltinTextEngine
      && typeof this.wasm.set_grid_text_renderer === "function"
      && typeof createCanvas2DTextRendererMaybe === "function") {
      const gridTextRenderer = createCanvas2DTextRendererMaybe(this.wasm);
      this.wasm.set_grid_text_renderer(
        this.grid.id,
        gridTextRenderer.measureText,
        gridTextRenderer.renderText,
      );
    }

    // Apply the spreadsheet theme via configure — WASM takes (grid_id, config_bytes) separately
    if (typeof this.wasm.volvox_grid_configure === "function") {
      const configBytes = encodeGridConfig(sheetConfig);
      const configResp = this.wasm.volvox_grid_configure(BigInt(this.grid.id), configBytes);
      if (configResp instanceof Uint8Array && configResp.length === 0) {
        if (typeof this.wasm.volvox_grid_last_error === "function") {
          const err = this.wasm.volvox_grid_last_error();
          if (err) console.warn("[VolvoxSheet] configure error:", err);
        }
      }
    }
    // Keep an explicit default size baseline even on builds where config
    // application is partial/older.
    this.grid.setFontSize(this.toEngineFontSize(this.defaultFontSize));
    this.grid.selectionMode = sheetConfig.selectionMode ?? 4;
    this.grid.showColumnHeaders = true;
    this.grid.columnIndicatorTopRowCount = 1;
    this.grid.showRowIndicator = true;
    this.grid.rowIndicatorStartModeBits = SHEET_ROW_INDICATOR_MODE;
    this.grid.rowIndicatorStartWidth = this.baseRowIndicatorStartWidth;
    this.applyIndicatorTheme();

    this.grid.setResizePolicy({ columns: true, rows: true, uniform: false });
    if (typeof this.grid.setHeaderResizeHandle === "function") {
      this.grid.setHeaderResizeHandle({ enabled: true });
    } else {
      this.grid.setHeaderResizeHandleStyle({ enabled: true });
    }

    // Enable double-click editing via the direct wrapper property (bypasses protobuf config)
    // 2 = EDIT_TRIGGER_KEY_CLICK: allows editing from RPC and dblclick.
    // host_key_dispatch=true still prevents engine from auto-starting on keypress.
    this.grid.editTrigger = 2;

    // Enable double-click-to-auto-size on column header borders
    if (typeof this.wasm.set_auto_size_mouse === "function") {
      this.wasm.set_auto_size_mouse(this.grid.id, 1);
    }

    // Host pointer dispatch: Sheet adapter owns all pointer-driven selection
    // and edit triggers.  Engine still handles resize, scrollbar, fast-scroll.
    if (typeof this.wasm.set_host_pointer_dispatch === "function") {
      this.wasm.set_host_pointer_dispatch(this.grid.id, 1);
    }

    // Full WASM mode needs one real font in the engine for shaping/measurement.
    // Lite mode uses browser text rendering, so skip the default fetch there.
    if (hasBuiltinTextEngine) {
      this.loadFont(explicitFontUrl || defaultFontSource.url);
    } else if (explicitFontUrl) {
      this.loadFont(explicitFontUrl);
    }

    // Initialize core modules
    this.keyDispatch = new KeyDispatch(options.keyBindings);
    this.editState = new EditStateMachine(
      this.wasm,
      this.grid.id,
      () => {
        this.flushPendingGridEventDecisions();
      },
    );
    this.selection = new SelectionModel(this.wasm, this.grid.id, this.grid);
    this.store = new DataStore(this.wasm, this.grid.id, this.grid);
    this.undoStack = new UndoRedoStack();
    this.clipboard = new ClipboardManager(this.store, this.undoStack);

    // Initialize data + headers
    this.store.init(options.data);
    this.installCancelableHooks(options);

    // Apply header alignment
    this.applyHeaderStyles();

    // UI: Toolbar
    if (options.showToolbar !== false) {
      this.toolbar = new Toolbar();
      this.toolbar.onAction = (action) => this.handleToolbarAction(action);
      this.rootEl.appendChild(this.toolbar.element);
    }

    // UI: Formula bar
    if (options.showFormulaBar !== false) {
      this.formulaBar = new FormulaBar(this.editState, this.selection, this.store);
      this.formulaBar.onCommit = (text) => this.commitFromFormulaBar(text);
      this.formulaBar.onCancel = () => {
        this.editState.cancelEdit();
        this.pendingEditOriginalRaw.clear();
        this.formulaBar?.updateFormulaInput();
        this.updateEditModeUI(false);
      };
      this.formulaBar.onNavigate = (r, c) => this.navigateToDataCell(r, c);
      this.formulaBar.onStartEdit = (text) => this.startEditWithSeed(text);
      this.rootEl.appendChild(this.formulaBar.element);
    }

    // Find/Replace bar (above canvas, hidden by default)
    this.findBar = new FindReplaceBar(this.store);
    this.findBar.onNavigate = (r, c) => this.navigateToDataCell(r, c);
    this.findBar.onReplace = (r, c, _old, newText) => {
      const oldRaw = this.store.getCellRawValue(r, c);
      const cmd = new CellValueChange(this.store, r, c, oldRaw, newText);
      this.undoStack.execute(cmd);
      this.updateToolbarState();
    };
    this.findBar.onReplaceAll = (replacements) => {
      const cmds = replacements
        .map((r) => {
          const oldRaw = this.store.getCellRawValue(r.row, r.col);
          return { row: r.row, col: r.col, oldRaw, newText: r.newText };
        })
        .filter(r => r.oldRaw !== r.newText)
        .map(r => new CellValueChange(this.store, r.row, r.col, r.oldRaw, r.newText));
      if (cmds.length > 0) {
        this.undoStack.execute(new BatchCommand(cmds, "Replace All"));
        this.updateToolbarState();
      }
    };
    this.rootEl.appendChild(this.findBar.element);

    // Canvas wrapper: position context for overlays (fill handle)
    this.canvasWrap = document.createElement("div");
    this.canvasWrap.className = "vx-canvas-wrap";
    this.canvasWrap.appendChild(this.canvas);
    this.rootEl.appendChild(this.canvasWrap);

    // Bottom bar: sheet tabs (left) + status bar (right) — Office 365 layout
    const bottomBar = document.createElement("div");
    bottomBar.className = "vx-bottom-bar";

    this.sheetTabs = new SheetTabs();
    this.sheetTabs.onSave = () => this.saveSheetSnapshot();
    this.sheetTabs.onLoad = (snap) => this.loadSheetSnapshot(snap);
    bottomBar.appendChild(this.sheetTabs.element);

    this.statusBar = new StatusBar();
    this.statusBar.onZoomChange = (percent) => {
      this.applyUserZoomScale(percent / 100);
    };
    this.statusBar.setZoom(this.userZoomScale * 100);
    bottomBar.appendChild(this.statusBar.element);

    this.rootEl.appendChild(bottomBar);

    this.container.appendChild(this.rootEl);
    this.grid.onZoomChange = (scale) => {
      const pinchBaseZoomScale = this.pinchBaseZoomScale ?? 1;
      const absoluteZoomScale = pinchBaseZoomScale * scale;
      const snappedZoomScale = this.snapPinchZoomScale(absoluteZoomScale);
      this.applyUserZoomScale(snappedZoomScale, {
        skipOverrideRescale: true,
        force: true,
      });
    };
    this.applyResponsiveLayout(true);
    if (typeof ResizeObserver !== "undefined") {
      this.layoutResizeObserver = new ResizeObserver(() => {
        this.applyResponsiveLayout();
      });
      this.layoutResizeObserver.observe(this.rootEl);
    }

    // Fill handle overlay on canvas
    this.fillHandle = new FillHandle(
      this.canvas, this.wasm, this.grid, this.store, this.selection, this.undoStack,
    );

    // UI: Context menu
    this.contextMenu = new ContextMenu();
    this.contextMenu.onAction = (action) => this.handleContextMenuAction(action);

    // Bind key events on canvas (idle mode)
    this.canvas.addEventListener("keydown", this.onKeyDown);
    this.canvas.addEventListener("pointerdown", this.onPointerDown);
    this.canvas.addEventListener("pointermove", this.onPointerMove);
    this.canvas.addEventListener("pointerup", this.onPointerUp);
    this.canvas.addEventListener("pointercancel", this.onPointerCancel);
    this.canvas.addEventListener("dblclick", this.onDblClick);
    this.canvas.addEventListener("contextmenu", this.onContextMenu);

    // Also bind on VolvoxGrid's editInput (appended to document.body)
    // so we intercept arrow keys etc. during editing.
    // Access via private field — editInput is created in VolvoxGrid constructor.
    this.gridEditInput = (this.grid as any).editInput as HTMLInputElement | null;
    if (this.gridEditInput) {
      // Use capture phase to fire BEFORE VolvoxGrid's own handler
      this.gridEditInput.addEventListener("keydown", this.onEditInputKeyDown, true);
      this.gridEditInput.addEventListener("focus", this.onEditInputFocus);
      this.gridEditInput.addEventListener("blur", this.onEditInputBlurCapture, true);
    }

    // Hook into VolvoxGrid's imeProxy composition-start callback so the
    // sheet's EditStateMachine is synchronously updated before editInput
    // gets focused (avoiding the onEditInputFocus guard rejection).
    // NOTE: The engine is already in editing mode (VolvoxGrid called
    // begin_edit_at_selection).  We only sync the JS-side state here.
    (this.grid as any).onCompositionEditStart = () => {
      const master = this.resolveMergedMaster(this.selection.row, this.selection.col);
      (this.grid as any).suppressEditorSelect = true;
      this.editState.onEngineStartEdit(master.row, master.col);
      this.updateEditModeUI(true);
      const dataRow = master.row;
      const dataCol = master.col;
      if (dataRow >= 0 && dataCol >= 0) {
        const key = `${dataRow}:${dataCol}`;
        this.pendingEditOriginalRaw.set(key, this.store.getCellRawValue(dataRow, dataCol));
      }
      requestAnimationFrame(() => {
        (this.grid as any).suppressEditorSelect = false;
      });
    };

    // Start event polling
    this.startEventPoll();

    // Initial selection
    this.selection.select(0, 0);
    this._preMergeRow = 0;
    this._preMergeCol = 0;
    this.formulaBar?.onSelectionChanged();

  }

  // ── Font loading ─────────────────────────────────────────

  private async loadFont(url: string): Promise<void> {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        console.warn(`VolvoxSheet: failed to fetch font from ${url}`);
        return;
      }
      const data = new Uint8Array(await response.arrayBuffer());
      if (typeof this.wasm.load_font === "function") {
        this.wasm.load_font(data);
        // Font loaded into shared registry — force grid repaint
        this.grid.invalidate();
      }
    } catch (err) {
      console.warn("VolvoxSheet: font load error", err);
    }
  }

  // ── Key handling ─────────────────────────────────────────

  private static NAV_KEYS = new Set([
    "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
    "PageUp", "PageDown", "Home", "End", "Tab",
  ]);
  private static FORMULA_REF_COLORS = [
    0xff4f81bd,
    0xffc0504d,
    0xff9bbb59,
    0xff8064a2,
    0xff4bacc6,
    0xfff79646,
  ] as const;

  private onKeyDown = (e: KeyboardEvent): void => {
    if (this.destroyed) return;
    if (this.contextMenu.isVisible) return;

    // Sync editing state: engine is the source of truth.
    const engineEditing = this.wasm.is_editing(this.grid.id) !== 0;
    if (this.editState.isEditing && !engineEditing) {
      this.editState.reset();
      this.updateEditModeUI(false);
    }

    const context = this.editState.isEditing ? "editing" : "idle";
    const action = this.keyDispatch.resolve(e, context);

    if (action) {
      e.preventDefault();
      e.stopPropagation();
      this.executeAction(action, e);
      return;
    }

    // Bare modifier keys have no action — don't forward to engine.
    if (e.key === "Shift" || e.key === "Control" || e.key === "Alt" || e.key === "Meta") {
      return;
    }

    // No matched action — forward to engine for navigation / scroll
    if (VolvoxSheet.NAV_KEYS.has(e.key)) {
      e.preventDefault();
    }
    const modifier = (e.shiftKey ? 1 : 0) | ((e.ctrlKey || e.metaKey) ? 2 : 0) | (e.altKey ? 4 : 0);
    this.wasm.handle_key_down(this.grid.id, e.keyCode, modifier);
    this.grid.invalidate();
  };

  /** Guard against syncHostEditor focusing editInput when we're not editing. */
  private onEditInputFocus = (): void => {
    if (this.destroyed) return;
    if (!this.editState.isEditing) {
      // Engine's syncHostEditor focused editInput, but we're not editing.
      // Refocus canvas to prevent key events from being swallowed.
      (this.grid as any).suppressBlurCommit = true;
      this.canvas.focus();
      (this.grid as any).suppressBlurCommit = false;
    }
  };

  /** Prevent host blur-commit while selecting formula references on the grid. */
  private onEditInputBlurCapture = (): void => {
    if (this.destroyed) return;
    if (!this.editState.isEditing || !this.editState.isFormulaMode) return;
    const gridAny = this.grid as any;
    gridAny.suppressBlurCommit = true;
    requestAnimationFrame(() => {
      if (!this.destroyed) {
        gridAny.suppressBlurCommit = false;
      }
    });
  };

  /** Keydown on VolvoxGrid's editInput — intercept editing-mode keys. */
  private onEditInputKeyDown = (e: KeyboardEvent): void => {
    if (this.destroyed) return;

    // Sync: if engine is no longer editing, reset adapter and refocus canvas.
    const engineEditing = this.wasm.is_editing(this.grid.id) !== 0;
    if (this.editState.isEditing && !engineEditing) {
      this.editState.reset();
      this.updateEditModeUI(false);
      this.focusCanvasClean();
      return; // Don't process this key on editInput; canvas will get next one
    }

    const isArrow = e.key === "ArrowLeft" || e.key === "ArrowRight"
                 || e.key === "ArrowUp" || e.key === "ArrowDown";
    const engineEditMode = this.getEngineEditUiMode();
    // In engine edit mode (F2/dblclick) and formula mode, arrow keys stay in
    // the input (do not auto-commit the edit session).
    if (isArrow && (engineEditMode === "edit" || this.editState.isFormulaMode)) {
      return; // let the input handle caret movement natively
    }

    // In engine enter mode (typed key / select-all edit), arrow keys commit and move.
    if (isArrow && engineEditMode !== "edit") {
      e.preventDefault();
      e.stopImmediatePropagation();
      this.commitEditAndNavigateArrow(e);
      return;
    }

    const action = this.keyDispatch.resolve(e, "editing");
    if (!action) return;

    e.preventDefault();
    e.stopImmediatePropagation();

    // Cancel: cancel the engine edit and clean up
    if (action === "cancelEdit") {
      if (typeof this.wasm.cancel_edit === "function" &&
          this.wasm.is_editing(this.grid.id) !== 0) {
        this.wasm.cancel_edit(this.grid.id);
      }
      this.editState.reset();
      this.pendingEditOriginalRaw.clear();
      this.updateEditModeUI(false);
      this.focusCanvasClean();
      return;
    }

    // Commit the engine edit directly
    if (!this.commitActiveHostEdit()) {
      return;
    }

    // Enter/Tab: engine ignores these with host_key_dispatch, move ourselves
    const moveMap: Partial<Record<SpreadsheetAction, [number, number]>> = {
      commitMoveDown: [1, 0],
      commitMoveUp: [-1, 0],
      commitMoveRight: [0, 1],
      commitMoveLeft: [0, -1],
    };
    const move = moveMap[action];
    if (move) {
      this.moveSelectionMergeAware(move[0], move[1]);
      this.onSelectionUpdated();
    }
  };

  /** Commit edit and navigate via arrow key (used in "enter" mode). */
  private commitEditAndNavigateArrow(e: KeyboardEvent): void {
    if (!this.commitActiveHostEdit()) {
      return;
    }

    const arrowDelta: Record<string, [number, number]> = {
      ArrowDown: [1, 0], ArrowUp: [-1, 0],
      ArrowRight: [0, 1], ArrowLeft: [0, -1],
    };
    const delta = arrowDelta[e.key];
    if (delta) {
      this.moveSelectionMergeAware(delta[0], delta[1]);
      this.onSelectionUpdated();
    }
  }

  /** Suppress VolvoxGrid's blur-commit and refocus canvas. */
  private focusCanvasClean(): void {
    // Reset editInput alignment to default before leaving edit mode
    if (this.gridEditInput) {
      this.gridEditInput.style.textAlign = "";
    }
    (this.grid as any).suppressBlurCommit = true;
    this.canvas.focus();
    (this.grid as any).suppressBlurCommit = false;
  }

  private getEngineEditUiMode(): "enter" | "edit" {
    if (typeof this.wasm.get_edit_ui_mode === "function"
      && this.wasm.is_editing(this.grid.id) !== 0) {
      return Number(this.wasm.get_edit_ui_mode(this.grid.id)) === 1 ? "edit" : "enter";
    }
    return "enter";
  }

  private setEngineEditUiMode(mode: "enter" | "edit"): void {
    if (typeof this.wasm.set_edit_ui_mode === "function"
      && this.wasm.is_editing(this.grid.id) !== 0) {
      this.wasm.set_edit_ui_mode(this.grid.id, mode === "edit" ? 1 : 0);
    }
  }

  private pointerToGridPixels(e: MouseEvent | PointerEvent): { x: number; y: number } {
    const rect = this.canvas.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    return {
      x: (e.clientX - rect.left) * dpr,
      y: (e.clientY - rect.top) * dpr,
    };
  }

  private pointerXInCell(e: MouseEvent | PointerEvent, row: number, col: number): number | null {
    if (typeof this.wasm.get_cell_screen_x !== "function") {
      return null;
    }
    const { x } = this.pointerToGridPixels(e);
    return x - Number(this.wasm.get_cell_screen_x(this.grid.id, row, col));
  }

  private syncHostEditSelectionFromEngine(): void {
    if (!this.gridEditInput
      || typeof this.wasm.get_edit_sel_start !== "function"
      || typeof this.wasm.get_edit_sel_length !== "function"
      || this.wasm.is_editing(this.grid.id) === 0) {
      return;
    }

    const value = this.gridEditInput.value;
    const chars = Array.from(value);
    const rawStart = Number(this.wasm.get_edit_sel_start(this.grid.id));
    const rawLength = Number(this.wasm.get_edit_sel_length(this.grid.id));
    if (!Number.isFinite(rawStart) || !Number.isFinite(rawLength)) {
      return;
    }

    const startChars = Math.max(0, Math.min(chars.length, rawStart));
    const endChars = Math.max(startChars, Math.min(chars.length, startChars + rawLength));
    const startUnits = chars.slice(0, startChars).join("").length;
    const endUnits = chars.slice(0, endChars).join("").length;
    this.gridEditInput.setSelectionRange(startUnits, endUnits);
  }

  private resolvePointerScope(
    e: MouseEvent | PointerEvent,
    row: number,
    col: number,
  ): ContextMenuScope {
    const { x, y } = this.pointerToGridPixels(e);
    const indicatorTopHeight = this.grid.showColumnHeaders
      ? this.currentColumnHeaderHeight * Math.max(0, this.grid.columnIndicatorTopRowCount)
      : 0;
    const indicatorStartWidth = this.grid.showRowIndicator
      ? this.grid.rowIndicatorStartWidth
      : 0;
    const inTop = y >= 0 && y < indicatorTopHeight;
    const inStart = x >= 0 && x < indicatorStartWidth;

    if (inTop && inStart) return "corner";
    if (inTop && col >= 0 && col < this.grid.colCount) return "colHeader";
    if (inStart && row >= 0 && row < this.grid.rowCount) return "rowHeader";
    if (row >= 0 && col >= 0 && row < this.grid.rowCount && col < this.grid.colCount) return "cell";
    return "outside";
  }

  // ── Pointer handling (adapter owns selection) ────────────

  /** Read the engine's hit-tested cell under the mouse. */
  private getMouseCell(): { row: number; col: number } {
    const row = typeof this.wasm.get_mouse_row === "function"
      ? Number(this.wasm.get_mouse_row(this.grid.id))
      : this.selection.row;
    const col = typeof this.wasm.get_mouse_col === "function"
      ? Number(this.wasm.get_mouse_col(this.grid.id))
      : this.selection.col;
    return { row, col };
  }

  private isAdditiveMultiRangePointer(e: PointerEvent): boolean {
    return this.grid.selectionMode === 4 && !e.shiftKey && (e.ctrlKey || e.metaKey);
  }

  private snapshotAdditiveRanges(anchorRow: number, anchorCol: number): CellRange[] {
    return this.selection.getRanges().filter((range) =>
      !(range.row1 === anchorRow
        && range.col1 === anchorCol
        && range.row2 === anchorRow
        && range.col2 === anchorCol),
    );
  }

  private buildAdditiveRanges(baseRanges: ReadonlyArray<CellRange>, targetRow: number, targetCol: number): CellRange[] {
    if (!this._multiRangeAnchor) {
      return [...baseRanges];
    }
    const nextRange: CellRange = {
      row1: Math.min(this._multiRangeAnchor.row, targetRow),
      col1: Math.min(this._multiRangeAnchor.col, targetCol),
      row2: Math.max(this._multiRangeAnchor.row, targetRow),
      col2: Math.max(this._multiRangeAnchor.col, targetCol),
    };
    const ranges = baseRanges.map((range) => ({ ...range }));
    const exists = ranges.some((range) =>
      range.row1 === nextRange.row1
      && range.col1 === nextRange.col1
      && range.row2 === nextRange.row2
      && range.col2 === nextRange.col2,
    );
    if (!exists) {
      ranges.push(nextRange);
    }
    return ranges;
  }

  private applyAdditiveSelection(targetRow: number, targetCol: number): void {
    const ranges = this.buildAdditiveRanges(this._multiRangeBaseRanges, targetRow, targetCol);
    this.selection.selectRanges(ranges, targetRow, targetCol);
    this._preMergeRow = targetRow;
    this._preMergeCol = targetCol;
    this.onSelectionUpdated();
  }

  private clearAdditivePointerSelection(): void {
    this._multiRangePointerDrag = false;
    this._multiRangeBaseRanges = [];
    this._multiRangeAnchor = null;
    this._multiRangeEnd = null;
  }

  private trackTouchPointerStart(e: PointerEvent): boolean {
    if (e.pointerType !== "touch") {
      return false;
    }
    this.activeTouchPointers.add(e.pointerId);
    if (this.activeTouchPointers.size >= 2) {
      if (this.pinchBaseZoomScale == null) {
        this.pinchBaseZoomScale = this.userZoomScale;
      }
      this._pointerDrag = false;
      this.clearAdditivePointerSelection();
      this._formulaDragRefSpan = null;
      return true;
    }
    return false;
  }

  private trackTouchPointerEnd(e: PointerEvent): void {
    if (e.pointerType !== "touch") {
      return;
    }
    this.activeTouchPointers.delete(e.pointerId);
    if (this.activeTouchPointers.size < 2) {
      this.pinchBaseZoomScale = null;
    }
  }

  private onPointerDown = (e: PointerEvent): void => {
    if (this.destroyed) return;
    if (this.trackTouchPointerStart(e)) return;

    const engineEditing = this.wasm.is_editing(this.grid.id) !== 0;
    if (this.editState.isEditing && !engineEditing) {
      this.editState.reset();
      this.updateEditModeUI(false);
      this.syncSelectionFromEngine();
      this.focusCanvasClean();
      return;
    }

    // Right-click: don't change selection (context menu handles it)
    if (e.button === 2) return;
    const formulaPickMode = this.editState.isEditing && this.editState.isFormulaMode;

    // If editing (non-formula), commit on click-away.
    // Formula mode keeps the edit session alive and repurposes selection to
    // insert/update references (Sheet-style point mode).
    if (this.editState.isEditing && !formulaPickMode) {
      if (!this.commitActiveHostEdit()) {
        return;
      }
      // Fall through to select the clicked cell
    }

    // Hit-test the fill handle before anything else
    if (!formulaPickMode && this.fillHandle) {
      const rect = this.canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      const px = (e.clientX - rect.left) * dpr;
      const py = (e.clientY - rect.top) * dpr;
      if (this.fillHandle.hitTestFillHandle(px, py)) {
        e.preventDefault();
        e.stopPropagation();
        this.fillHandle.startDrag();
        return;
      }
    }

    if (formulaPickMode) {
      clearTimeout(this.singleClickTimer);
      const { row, col } = this.getMouseCell();
      if (this.resolvePointerScope(e, row, col) !== "cell") {
        return;
      }
      if (e.shiftKey) {
        this.selection.select(this.selection.row, this.selection.col, row, col);
      } else {
        this.selection.select(row, col);
      }
      this._preMergeRow = row;
      this._preMergeCol = col;
      this._pointerDragAnchor = { row: this.selection.row, col: this.selection.col };
      this._pointerDrag = true;
      this.upsertFormulaReferenceFromSelection(true);
      this.onSelectionUpdated();
      return;
    }

    // Left click: select the cell under the pointer.
    // Engine already ran handle_pointer_down (updates mouse_row/col).
    const { row, col } = this.getMouseCell();
    const scope = this.resolvePointerScope(e, row, col);
    if (scope === "outside") return;

    if (scope === "cell") {
      const prevKey = `${this.selection.row}:${this.selection.col}`;
      const cellKey = `${row}:${col}`;
      const additiveMultiRange = this.isAdditiveMultiRangePointer(e);

      if (additiveMultiRange) {
        clearTimeout(this.singleClickTimer);
        this.lastClickedCell = "";
        this._multiRangeBaseRanges = this.snapshotAdditiveRanges(row, col);
        this._multiRangeAnchor = { row, col };
        this._multiRangeEnd = { row, col };
        this._multiRangePointerDrag = true;
        this.applyAdditiveSelection(row, col);
      } else if (e.shiftKey) {
        // Shift-click: extend selection from anchor
        this.selection.select(
          this.selection.row, this.selection.col,
          row, col,
        );
      } else {
        this.selection.select(row, col);
      }
      this._preMergeRow = row;
      this._preMergeCol = col;
      this._pointerDragAnchor = additiveMultiRange ? null : { row: this.selection.row, col: this.selection.col };
      if (!additiveMultiRange) {
        this.onSelectionUpdated();
      }

      // Single-click-to-edit: if clicking the same already-selected cell
      if (!additiveMultiRange && !e.shiftKey && cellKey === this.lastClickedCell && cellKey === prevKey) {
        clearTimeout(this.singleClickTimer);
        this.singleClickTimer = window.setTimeout(() => {
          if (this.destroyed || this.editState.isEditing) return;
          if (`${this.selection.row}:${this.selection.col}` === cellKey) {
            const master = this.resolveMergedMaster(this.selection.row, this.selection.col);
            const masterDataRow = master.row;
            const masterDataCol = master.col;
            const started = this.editState.startEdit(master.row, master.col, {
              selectAll: true,
              currentText: this.store.getCellRawValue(masterDataRow, masterDataCol),
            });
            if (started) {
              this.setEngineEditUiMode("edit");
              this.updateEditModeUI(true);
              requestAnimationFrame(() => this.syncEditInputAlign());
            }
          }
        }, 300);
      } else {
        clearTimeout(this.singleClickTimer);
      }
      this.lastClickedCell = additiveMultiRange ? "" : cellKey;

      // Start drag-select tracking
      if (additiveMultiRange) {
        this._pointerDrag = false;
      } else if (!e.shiftKey) {
        this._pointerDrag = true;
      }
    } else {
      clearTimeout(this.singleClickTimer);
      this._pointerDragAnchor = null;
      this.clearAdditivePointerSelection();
      if (scope === "rowHeader") {
        this.selection.select(row, 0, row, this.grid.colCount - 1);
        this.onSelectionUpdated();
      } else if (scope === "colHeader") {
        this.selection.select(0, col, this.grid.rowCount - 1, col);
        this.onSelectionUpdated();
      } else if (scope === "corner") {
        this.selection.select(0, 0, this.grid.rowCount - 1, this.grid.colCount - 1);
        this.onSelectionUpdated();
      }
    }
  };

  private onPointerMove = (e: PointerEvent): void => {
    if (this.destroyed) return;
    if (e.pointerType === "touch" && this.activeTouchPointers.size >= 2) return;
    if (this._multiRangePointerDrag) {
      if (!(e.buttons & 1)) {
        this.clearAdditivePointerSelection();
        return;
      }
      const { row, col } = this.getMouseCell();
      if (row >= 0 && col >= 0) {
        if (!this._multiRangeEnd
          || row !== this._multiRangeEnd.row
          || col !== this._multiRangeEnd.col) {
          this._multiRangeEnd = { row, col };
          this.applyAdditiveSelection(row, col);
        }
      }
      return;
    }
    if (!this._pointerDrag) return;
    if (!(e.buttons & 1)) { this._pointerDrag = false; return; }

    if (this.editState.isEditing && this.editState.isFormulaMode) {
      const { row, col } = this.getMouseCell();
      if (row >= 0 && col >= 0) {
        if (row !== this.selection.rowEnd || col !== this.selection.colEnd) {
          const anchor = this._pointerDragAnchor ?? { row: this.selection.row, col: this.selection.col };
          this.selection.select(
            anchor.row, anchor.col,
            row, col,
          );
          this.upsertFormulaReferenceFromSelection(false);
          this.onSelectionUpdated();
        }
      }
      return;
    }

    // Extend selection to current mouse cell
    const { row, col } = this.getMouseCell();
    if (row >= 0 && col >= 0) {
      if (row !== this.selection.rowEnd || col !== this.selection.colEnd) {
        const anchor = this._pointerDragAnchor ?? { row: this.selection.row, col: this.selection.col };
        this.selection.select(
          anchor.row, anchor.col,
          row, col,
        );
        this.onSelectionUpdated();
      }
    }
  };

  private onPointerUp = (e: PointerEvent): void => {
    this.trackTouchPointerEnd(e);
    this._pointerDrag = false;
    this._pointerDragAnchor = null;
    this.clearAdditivePointerSelection();
    this._formulaDragRefSpan = null;
  };

  private onPointerCancel = (e: PointerEvent): void => {
    this.trackTouchPointerEnd(e);
    this._pointerDrag = false;
    this._pointerDragAnchor = null;
    this.clearAdditivePointerSelection();
    this._formulaDragRefSpan = null;
  };

  // ── Double-click to edit ──────────────────────────────────

  private onDblClick = (e: MouseEvent): void => {
    if (this.destroyed) return;
    clearTimeout(this.singleClickTimer);

    const row = this.selection.row;
    const col = this.selection.col;
    if (row < 0 || col < 0) return;

    const master = this.resolveMergedMaster(row, col);
    const masterDataRow = master.row;
    const masterDataCol = master.col;

    (this.grid as any).suppressEditorSelect = true;
    const engineEditing = this.wasm.is_editing(this.grid.id) !== 0;
    const cellText = this.store.getCellRawValue(masterDataRow, masterDataCol);
    const clickXInCell = this.pointerXInCell(e, master.row, master.col);

    let usedFallbackEditStart = false;
    if (!engineEditing) {
      // Engine didn't start editing — force it
      if (this.tryBeginDirectEdit(master.row, master.col, clickXInCell)) {
        // Engine is now editing — sync adapter state immediately so the
        // editInput focus guard doesn't reject focus before drainEvents
        // processes the StartEdit event.
        this.editState.syncActiveEdit(master.row, master.col, cellText);
        this.updateEditModeUI(true);
      } else {
        // Still not editing — try adapter RPC path
        const started = this.editState.startEdit(master.row, master.col, {
          selectAll: true,
          currentText: cellText,
        });
        if (started) {
          usedFallbackEditStart = true;
          this.setEngineEditUiMode("edit");
          this.updateEditModeUI(true);
        }
      }
    }
    if (!this.editState.isEditing && this.wasm.is_editing(this.grid.id) === 0) {
      (this.grid as any).suppressEditorSelect = false;
      return;
    }

    requestAnimationFrame(() => {
      this.syncEditInputAlign();
      if (usedFallbackEditStart && cellText) {
        this.positionCaretFromClick(e.clientX, cellText);
      } else {
        this.syncHostEditSelectionFromEngine();
      }
      (this.grid as any).suppressEditorSelect = false;
    });
  };

  /** Approximate character position from click X and set caret. */
  private positionCaretFromClick(clientX: number, text: string): void {
    const input = this.gridEditInput;
    if (!input || input.style.display === "none") return;

    // Use the input's computed font for measurement
    const style = getComputedStyle(input);
    const font = `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
    const paddingLeft = parseFloat(style.paddingLeft) || 0;
    const paddingRight = parseFloat(style.paddingRight) || 0;

    const inputRect = input.getBoundingClientRect();
    const contentWidth = inputRect.width - paddingLeft - paddingRight;

    // Measure total text width
    const offscreen = document.createElement("canvas");
    const ctx = offscreen.getContext("2d")!;
    ctx.font = font;
    const textWidth = ctx.measureText(text).width;

    // Compute the X offset from the text origin, accounting for alignment
    // and the input's scroll position.
    const gridRow = this.selection.row;
    const gridCol = this.selection.col;
    const align = this.cellAlignments.get(`${gridRow}:${gridCol}`) ?? 0;
    const hAlign = Math.floor(align / 3); // 0=left, 1=center, 2=right

    // Where text origin is within the input's coordinate space
    // (relative to inputRect.left + paddingLeft, before scroll)
    let textOrigin = 0; // left-aligned default
    if (hAlign === 2) {
      // Right-aligned: text end flush with right padding edge
      textOrigin = contentWidth - textWidth;
    } else if (hAlign === 1) {
      // Center-aligned
      textOrigin = (contentWidth - textWidth) / 2;
    }

    // Convert clientX to a position along the text's own axis.
    // The visible portion of the input content is shifted by scrollLeft.
    const scrollLeft = input.scrollLeft;
    const offsetX = (clientX - inputRect.left - paddingLeft) + scrollLeft - textOrigin;

    if (offsetX <= 0) {
      this.setCaretPosition(0);
      return;
    }

    // Measure text prefix widths to find the character boundary
    let pos = text.length; // default: end
    for (let i = 0; i <= text.length; i++) {
      const w = ctx.measureText(text.substring(0, i)).width;
      if (w >= offsetX) {
        if (i > 0) {
          const prevW = ctx.measureText(text.substring(0, i - 1)).width;
          pos = (offsetX - prevW < w - offsetX) ? i - 1 : i;
        } else {
          pos = 0;
        }
        break;
      }
    }

    this.setCaretPosition(pos);
  }

  /** Set caret position on both the HTML input and the engine. */
  private setCaretPosition(pos: number): void {
    if (this.gridEditInput) {
      this.gridEditInput.setSelectionRange(pos, pos);
    }
    if (typeof this.wasm.set_edit_selection === "function") {
      this.wasm.set_edit_selection(this.grid.id, pos, 0);
    }
  }

  private getEditCaretPosition(defaultPos: number): number {
    if (this.gridEditInput && typeof this.gridEditInput.selectionStart === "number") {
      const pos = this.gridEditInput.selectionStart;
      return Math.max(0, Math.min(defaultPos, pos));
    }
    return defaultPos;
  }

  private formatRangeA1(range: CellRange): string {
    const row1 = Math.min(range.row1, range.row2);
    const col1 = Math.min(range.col1, range.col2);
    const row2 = Math.max(range.row1, range.row2);
    const col2 = Math.max(range.col1, range.col2);
    if (row1 === row2 && col1 === col2) {
      return toA1(row1, col1);
    }
    return `${toA1(row1, col1)}:${toA1(row2, col2)}`;
  }

  private setEditTextFromFormulaMode(text: string, caretPos: number): void {
    if (typeof this.wasm.volvox_grid_edit_pb === "function") {
      const req = encodeEditSetText({
        gridId: this.grid.id,
        text,
      });
      this.wasm.volvox_grid_edit_pb(req);
    } else if (typeof this.wasm.set_edit_text === "function") {
      this.wasm.set_edit_text(this.grid.id, text);
    }

    if (this.gridEditInput) {
      this.gridEditInput.value = text;
      this.gridEditInput.focus();
    }
    this.editState.onEditTextChanged(text);
    this.formulaBar?.onEditTextChanged(text);
    this.setCaretPosition(caretPos);
    this.syncFormulaHighlightsFromText(text);
  }

  private findPrevNonWhitespace(text: string, from: number): number {
    let i = Math.min(from, text.length - 1);
    while (i >= 0 && /\s/.test(text[i])) {
      i -= 1;
    }
    return i;
  }

  private findNextNonWhitespace(text: string, from: number): number {
    let i = Math.max(0, from);
    while (i < text.length && /\s/.test(text[i])) {
      i += 1;
    }
    return i < text.length ? i : -1;
  }

  private needsFormulaArgSeparator(text: string, insertPos: number): boolean {
    const prevIdx = this.findPrevNonWhitespace(text, insertPos - 1);
    if (prevIdx < 0) return false;
    const prev = text[prevIdx];
    if (prev === "=" || prev === ":" || /[,(+\-*/^&<>]/.test(prev)) {
      return false;
    }
    return true;
  }

  private findFormulaReferenceAtCaret(refs: FormulaRefToken[], caretPos: number): FormulaRefToken | null {
    for (const ref of refs) {
      const end = ref.start + ref.length;
      if (caretPos >= ref.start && caretPos <= end) {
        return ref;
      }
    }
    return null;
  }

  private insertFormulaReferenceToken(text: string, refText: string): {
    text: string;
    caretPos: number;
    span: { start: number; length: number };
  } {
    const caretPos = this.getEditCaretPosition(text.length);
    const refs = this.parseFormulaReferences(text);
    const currentRef = this.findFormulaReferenceAtCaret(refs, caretPos);

    let start = caretPos;
    let end = caretPos;
    let prefix = "";

    if (currentRef) {
      start = currentRef.start;
      end = currentRef.start + currentRef.length;
    } else if (this.needsFormulaArgSeparator(text, caretPos)) {
      const nextIdx = this.findNextNonWhitespace(text, caretPos);
      if (nextIdx < 0 || text[nextIdx] !== ",") {
        prefix = ",";
      }
    }

    const replacement = `${prefix}${refText}`;
    const newText = text.slice(0, start) + replacement + text.slice(end);
    const refStart = start + prefix.length;
    return {
      text: newText,
      caretPos: refStart + refText.length,
      span: { start: refStart, length: refText.length },
    };
  }

  private replaceFormulaReferenceToken(
    text: string,
    refText: string,
    span: { start: number; length: number },
  ): {
    text: string;
    caretPos: number;
    span: { start: number; length: number };
  } {
    const start = Math.max(0, Math.min(text.length, span.start));
    const end = Math.max(start, Math.min(text.length, span.start + span.length));
    const newText = text.slice(0, start) + refText + text.slice(end);
    return {
      text: newText,
      caretPos: start + refText.length,
      span: { start, length: refText.length },
    };
  }

  private upsertFormulaReferenceFromSelection(startNewToken: boolean): void {
    if (!this.editState.isEditing || !this.editState.isFormulaMode) return;

    const range = this.selection.getRange();
    if (range.row1 < 0 || range.col1 < 0 || range.row2 < 0 || range.col2 < 0) {
      return;
    }

    const currentText = this.editState.currentText;
    if (!currentText.trimStart().startsWith("=")) {
      this.clearFormulaHighlights();
      return;
    }

    const refText = this.formatRangeA1(range);
    const result = !startNewToken && this._formulaDragRefSpan
      ? this.replaceFormulaReferenceToken(currentText, refText, this._formulaDragRefSpan)
      : this.insertFormulaReferenceToken(currentText, refText);

    this._formulaDragRefSpan = result.span;
    this.setEditTextFromFormulaMode(result.text, result.caretPos);
  }

  private isFormulaRefBoundaryChar(ch: string | undefined): boolean {
    if (ch == null) return true;
    return !/[A-Za-z0-9_$.]/.test(ch);
  }

  private parseA1CellToken(token: string): { row: number; col: number } | null {
    const match = token.match(/^(\$?)([A-Za-z]+)(\$?)(\d+)$/);
    if (!match) return null;
    const col = letterToCol(match[2].toUpperCase());
    const row = Number.parseInt(match[4], 10) - 1;
    if (!Number.isFinite(row) || !Number.isFinite(col) || row < 0 || col < 0) {
      return null;
    }
    return { row, col };
  }

  private parseA1ColumnToken(token: string): number | null {
    const match = token.match(/^\$?([A-Za-z]+)$/);
    if (!match) return null;
    const col = letterToCol(match[1].toUpperCase());
    return Number.isFinite(col) && col >= 0 ? col : null;
  }

  private parseA1RowToken(token: string): number | null {
    const match = token.match(/^\$?(\d+)$/);
    if (!match) return null;
    const row = Number.parseInt(match[1], 10) - 1;
    return Number.isFinite(row) && row >= 0 ? row : null;
  }

  private parseFormulaTokenRange(
    token: string,
    maxRow: number,
    maxCol: number,
  ): { row1: number; col1: number; row2: number; col2: number } | null {
    if (maxRow < 0 || maxCol < 0) return null;

    const clampRange = (row1: number, col1: number, row2: number, col2: number) => {
      const r1 = Math.max(0, Math.min(maxRow, Math.min(row1, row2)));
      const c1 = Math.max(0, Math.min(maxCol, Math.min(col1, col2)));
      const r2 = Math.max(0, Math.min(maxRow, Math.max(row1, row2)));
      const c2 = Math.max(0, Math.min(maxCol, Math.max(col1, col2)));
      if (r1 > r2 || c1 > c2) return null;
      return { row1: r1, col1: c1, row2: r2, col2: c2 };
    };

    if (token.includes(":")) {
      const parts = token.split(":");
      if (parts.length !== 2) return null;
      const left = parts[0];
      const right = parts[1];

      const leftCell = this.parseA1CellToken(left);
      const rightCell = this.parseA1CellToken(right);
      if (leftCell && rightCell) {
        return clampRange(leftCell.row, leftCell.col, rightCell.row, rightCell.col);
      }

      const leftCol = this.parseA1ColumnToken(left);
      const rightCol = this.parseA1ColumnToken(right);
      if (leftCol != null && rightCol != null) {
        return clampRange(0, leftCol, maxRow, rightCol);
      }

      const leftRow = this.parseA1RowToken(left);
      const rightRow = this.parseA1RowToken(right);
      if (leftRow != null && rightRow != null) {
        return clampRange(leftRow, 0, rightRow, maxCol);
      }
      return null;
    }

    const cell = this.parseA1CellToken(token);
    if (cell) {
      return clampRange(cell.row, cell.col, cell.row, cell.col);
    }

    return null;
  }

  private parseFormulaReferences(text: string): FormulaRefToken[] {
    if (!text.trimStart().startsWith("=")) {
      return [];
    }
    const maxRow = this.grid.rowCount - 0 - 1;
    const maxCol = this.grid.colCount - 0 - 1;
    if (maxRow < 0 || maxCol < 0) {
      return [];
    }

    const refs: FormulaRefToken[] = [];
    let i = 0;
    let inString = false;
    while (i < text.length) {
      const ch = text[i];
      if (ch === "\"") {
        if (inString && i + 1 < text.length && text[i + 1] === "\"") {
          i += 2;
          continue;
        }
        inString = !inString;
        i += 1;
        continue;
      }
      if (inString || !/[A-Za-z0-9$]/.test(ch)) {
        i += 1;
        continue;
      }

      const prev = i > 0 ? text[i - 1] : undefined;
      if (!this.isFormulaRefBoundaryChar(prev)) {
        i += 1;
        continue;
      }

      const rest = text.slice(i);
      const candidates: Array<RegExpMatchArray | null> = [
        rest.match(/^\$?[A-Za-z]+\$?\d+:\$?[A-Za-z]+\$?\d+/),
        rest.match(/^\$?[A-Za-z]+:\$?[A-Za-z]+/),
        rest.match(/^\$?\d+:\$?\d+/),
        rest.match(/^\$?[A-Za-z]+\$?\d+/),
      ];
      const match = candidates.find((m) => m != null);
      if (!match) {
        i += 1;
        continue;
      }

      const token = match[0];
      const end = i + token.length;
      const next = end < text.length ? text[end] : undefined;
      if (!this.isFormulaRefBoundaryChar(next)) {
        i += 1;
        continue;
      }

      const parsed = this.parseFormulaTokenRange(token, maxRow, maxCol);
      if (parsed) {
        refs.push({
          start: i,
          length: token.length,
          row1: parsed.row1,
          col1: parsed.col1,
          row2: parsed.row2,
          col2: parsed.col2,
        });
      }
      i = end;
    }

    return refs;
  }

  private sendEditHighlights(regions: HighlightRegionArg[]): void {
    if (typeof this.wasm.volvox_grid_edit_pb !== "function") return;
    const req = encodeEditSetHighlights({
      gridId: this.grid.id,
      regions,
    });
    this.wasm.volvox_grid_edit_pb(req);
  }

  private clearFormulaHighlights(): void {
    this._formulaDragRefSpan = null;
    this.sendEditHighlights([]);
  }

  private syncFormulaHighlightsFromText(text: string = this.editState.currentText): void {
    if (!this.editState.isEditing || !text.trimStart().startsWith("=")) {
      this.clearFormulaHighlights();
      return;
    }

    const refs = this.parseFormulaReferences(text);
    if (refs.length === 0) {
      this.clearFormulaHighlights();
      return;
    }

    const rowOffset = 0;
    const colOffset = 0;
    const regions: HighlightRegionArg[] = refs.map((ref, idx) => ({
      row1: ref.row1 + rowOffset,
      col1: ref.col1 + colOffset,
      row2: ref.row2 + rowOffset,
      col2: ref.col2 + colOffset,
      style: {
        borders: { all: { color: VolvoxSheet.FORMULA_REF_COLORS[idx % VolvoxSheet.FORMULA_REF_COLORS.length] } },
        fillHandle: 5, // FILL_HANDLE_ALL_CORNERS
      },
      refId: idx + 1,
      textStart: ref.start,
      textLength: ref.length,
    }));
    this.sendEditHighlights(regions);
  }

  private executeAction(action: SpreadsheetAction, e?: KeyboardEvent): void {
    switch (action) {
      // ── Idle actions ──
      case "startEdit": {
        const key = e?.key;
        const isPrintable = key != null && key.length === 1 && !e?.ctrlKey && !e?.metaKey;
        if (isPrintable) {
          this.startEditWithSeed(key);
        } else {
          const master = this.resolveMergedMaster(this.selection.row, this.selection.col);
          const masterDataRow = master.row - 0;
          const masterDataCol = master.col - 0;
          const started = this.editState.startEdit(master.row, master.col, {
            selectAll: true,
            currentText: this.store.getCellRawValue(masterDataRow, masterDataCol),
          });
          if (started) {
            this.updateEditModeUI(true);
            requestAnimationFrame(() => this.syncEditInputAlign());
          }
        }
        break;
      }
      case "startEditCaretEnd": {
        (this.grid as any).suppressEditorSelect = true;
        const master = this.resolveMergedMaster(this.selection.row, this.selection.col);
        const masterDataRow = master.row - 0;
        const masterDataCol = master.col - 0;
        const cellText = this.store.getCellRawValue(masterDataRow, masterDataCol);
        const started = this.editState.startEdit(master.row, master.col, {
          caretEnd: true,
          currentText: cellText,
        });
        if (started) {
          this.setEngineEditUiMode("edit");
          this.updateEditModeUI(true);
          requestAnimationFrame(() => {
            this.syncEditInputAlign();
            // F2: caret at end, no selection
            this.setCaretPosition(cellText.length);
            (this.grid as any).suppressEditorSelect = false;
          });
        } else {
          (this.grid as any).suppressEditorSelect = false;
        }
        break;
      }
      case "startEditClear":
        this.startEditWithSeed("");
        break;
      case "clearCell":
        this.clearSelectedCells();
        this.updateToolbarState();
        break;
      case "moveDown":
        this.moveSelectionMergeAware(1, 0);
        this.onSelectionUpdated();
        break;
      case "moveUp":
        this.moveSelectionMergeAware(-1, 0);
        this.onSelectionUpdated();
        break;
      case "moveRight":
        this.moveSelectionMergeAware(0, 1);
        this.onSelectionUpdated();
        break;
      case "moveLeft":
        this.moveSelectionMergeAware(0, -1);
        this.onSelectionUpdated();
        break;

      // ── Editing actions ──
      case "commitMoveDown":
        this.commitAndMove(1, 0);
        break;
      case "commitMoveUp":
        this.commitAndMove(-1, 0);
        break;
      case "commitMoveRight":
        this.commitAndMove(0, 1);
        break;
      case "commitMoveLeft":
        this.commitAndMove(0, -1);
        break;
      case "cancelEdit":
        this.editState.cancelEdit();
        this.pendingEditOriginalRaw.clear();
        this.formulaBar?.updateFormulaInput();
        this.updateEditModeUI(false);
        break;

      // ── Common actions ──
      case "undo":
        this.undoStack.undo();
        this.updateToolbarState();
        break;
      case "redo":
        this.undoStack.redo();
        this.updateToolbarState();
        break;
      case "copy":
        this.copy();
        break;
      case "cut":
        this.cut();
        break;
      case "paste":
        this.paste();
        break;
      case "selectAll":
        this.selection.select(
          0, 0,
          this.grid.rowCount - 1, this.grid.colCount - 1,
        );
        this.onSelectionUpdated();
        break;
      case "toggleBold":
        this.toggleStyle("fontBold");
        break;
      case "toggleItalic":
        this.toggleStyle("fontItalic");
        break;
      case "toggleUnderline":
        this.toggleStyle("fontUnderline");
        break;
      case "find":
        this.findBar?.show(false);
        break;
      case "findReplace":
        this.findBar?.show(true);
        break;
      case "noop":
        break;
    }
  }

  private flushPendingGridEventDecisions(): boolean {
    const grid = this.grid as VolvoxSheetGrid & {
      flushPendingEventDecisions?: () => boolean;
    };
    if (typeof grid.flushPendingEventDecisions !== "function") {
      return false;
    }
    return grid.flushPendingEventDecisions();
  }

  private installCancelableHooks(options: VolvoxSheetOptions): void {
    this.grid.onBeforeEdit = options.onBeforeEdit == null
      ? null
      : (details) => {
          const event = {
            row: details.row,
            col: details.col,
            value: this.store.getCellRawValue(details.row, details.col),
            cancel: false,
          };
          options.onBeforeEdit?.(event);
          details.cancel = event.cancel;
        };

    this.grid.onCellEditValidating = options.onCellEditValidating == null
      ? null
      : (details) => {
          const event = {
            row: details.row,
            col: details.col,
            oldText: this.store.getCellRawValue(details.row, details.col),
            newText: details.editText,
            cancel: false,
          };
          options.onCellEditValidating?.(event);
          details.cancel = event.cancel;
        };
  }

  private commitActiveHostEdit(): boolean {
    if (typeof this.wasm.commit_edit !== "function"
      || this.wasm.is_editing(this.grid.id) === 0) {
      return false;
    }
    if (this.gridEditInput) {
      this.wasm.set_edit_text(this.grid.id, this.gridEditInput.value);
    }
    this.wasm.commit_edit(this.grid.id);
    this.flushPendingGridEventDecisions();
    if (this.wasm.is_editing(this.grid.id) !== 0) {
      this.updateEditModeUI(true);
      requestAnimationFrame(() => this.syncEditInputAlign());
      return false;
    }
    this.editState.reset();
    this.updateEditModeUI(false);
    this.focusCanvasClean();
    return true;
  }

  private tryBeginDirectEdit(row: number, col: number, clickXInCell?: number | null): boolean {
    if (typeof clickXInCell === "number"
      && Number.isFinite(clickXInCell)
      && typeof this.wasm.begin_edit_cell_at_click === "function") {
      this.wasm.begin_edit_cell_at_click(this.grid.id, row, col, clickXInCell);
    } else if (typeof this.wasm.begin_edit_cell === "function") {
      this.wasm.begin_edit_cell(this.grid.id, row, col);
    } else if (typeof this.wasm.begin_edit_at_selection === "function") {
      this.wasm.begin_edit_at_selection(this.grid.id);
    }
    this.flushPendingGridEventDecisions();
    return this.wasm.is_editing(this.grid.id) !== 0;
  }

  // ── Edit helpers ─────────────────────────────────────────

  /** Sync editInput text-align with the current cell's alignment. */
  private syncEditInputAlign(): void {
    if (!this.gridEditInput) return;
    const key = `${this.selection.row}:${this.selection.col}`;
    const align = this.cellAlignments.get(key) ?? 0;
    const hAlign = Math.floor(align / 3);
    this.gridEditInput.style.textAlign =
      hAlign === 2 ? "right" : hAlign === 1 ? "center" : "";

    // Keep host edit input typography in sync with the active cell style.
    const style = this.cellStyleCache.get(key) ?? {};
    const fontSize =
      typeof style.fontSize === "number" && Number.isFinite(style.fontSize) && style.fontSize > 0
        ? style.fontSize
        : this.defaultFontSize;
    this.gridEditInput.style.fontSize = `${this.toCssFontSizePx(fontSize)}px`;
    this.gridEditInput.style.fontWeight = style.fontBold ? "700" : "";
    this.gridEditInput.style.fontStyle = style.fontItalic ? "italic" : "";
  }

  private startEditWithSeed(seedText: string): void {
    const master = this.resolveMergedMaster(this.selection.row, this.selection.col);
    const masterDataRow = master.row - 0;
    const masterDataCol = master.col - 0;
    (this.grid as any).suppressEditorSelect = true;
    const started = this.editState.startEdit(master.row, master.col, {
      seedText,
      currentText: this.store.getCellRawValue(masterDataRow, masterDataCol),
    });
    if (!started) {
      (this.grid as any).suppressEditorSelect = false;
      return;
    }
    this.updateEditModeUI(true);
    requestAnimationFrame(() => {
      this.syncEditInputAlign();
      if (this.gridEditInput) {
        this.gridEditInput.value = seedText;
        this.setCaretPosition(seedText.length);
      }
      (this.grid as any).suppressEditorSelect = false;
    });
  }

  private commitAndMove(dRow: number, dCol: number): void {
    const result = this.editState.commitEdit();
    if (result == null) {
      return;
    }
    if (result?.canceled) {
      this.updateEditModeUI(true);
      this.formulaBar?.updateFormulaInput();
      requestAnimationFrame(() => this.syncEditInputAlign());
      return;
    }
    // EVENT_AFTER_EDIT is the single source of truth for edit undo history.
    if (result && result.oldText !== result.newText) {
      // no-op
    }
    this.updateEditModeUI(false);
    this.moveSelectionMergeAware(dRow, dCol);
    this.onSelectionUpdated();
  }

  private commitFromFormulaBar(text: string): void {
    if (this.editState.isEditing) {
      const result = this.editState.commitEdit(text);
      if (result?.canceled) {
        this.updateEditModeUI(true);
        this.formulaBar?.updateFormulaInput();
        requestAnimationFrame(() => this.syncEditInputAlign());
        return;
      }
      // EVENT_AFTER_EDIT records undo/history after engine commit.
      if (result && result.oldText !== text) {
        // no-op
      }
    } else {
      // Direct cell value change (no active edit session)
      const master = this.resolveMergedMaster(this.selection.row, this.selection.col);
      const masterDataRow = master.row - 0;
      const masterDataCol = master.col - 0;
      const oldText = this.store.getCellRawValue(masterDataRow, masterDataCol);
      if (oldText !== text) {
        const cmd = new CellValueChange(
          this.store, masterDataRow, masterDataCol,
          oldText, text,
        );
        this.undoStack.execute(cmd);
        this.updateToolbarState();
      }
    }
    this.updateEditModeUI(false);
    this.formulaBar?.updateFormulaInput();
    this.canvas.focus();
  }

  private clearSelectedCells(): void {
    const sel = this.selection.getRange();
    const maxRow = this.grid.rowCount - 0 - 1;
    const maxCol = this.grid.colCount - 0 - 1;
    if (maxRow < 0 || maxCol < 0) return;
    const range = {
      row1: Math.max(0, sel.row1),
      col1: Math.max(0, sel.col1),
      row2: Math.min(maxRow, sel.row2),
      col2: Math.min(maxCol, sel.col2),
    };
    if (range.row1 > range.row2 || range.col1 > range.col2) return;

    const commands: CellValueChange[] = [];
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const old = this.store.getCellRawValue(r, c);
        if (old !== "") {
          commands.push(new CellValueChange(this.store, r, c, old, ""));
        }
      }
    }
    if (commands.length === 1) {
      this.undoStack.execute(commands[0]);
    } else if (commands.length > 1) {
      this.undoStack.execute(new BatchCommand(commands, "Clear cells"));
    }
  }

  // ── Numeric auto-alignment ──────────────────────────────

  private static NUMERIC_RE = /^-?\d+(\.\d+)?([eE][+-]?\d+)?$/;

  private autoAlignCell(dataRow: number, dataCol: number, text: string): void {
    const gridRow = dataRow + 0;
    const gridCol = dataCol + 0;
    const key = `${gridRow}:${gridCol}`;

    if (VolvoxSheet.NUMERIC_RE.test(text.trim())) {
      this.store.batchUpdateCells([{ row: gridRow, col: gridCol, style: { alignment: ALIGN.RIGHT_CENTER } }]);
      this.cacheAlignment(gridRow, gridCol, ALIGN.RIGHT_CENTER);
      this.cacheCellStyle(gridRow, gridCol, { alignment: ALIGN.RIGHT_CENTER });
      this.autoAligned.add(key);
      this.grid.invalidate();
    } else if (this.autoAligned.has(key)) {
      this.store.batchUpdateCells([{ row: gridRow, col: gridCol, style: { alignment: ALIGN.LEFT_CENTER } }]);
      this.cacheAlignment(gridRow, gridCol, ALIGN.LEFT_CENTER);
      this.cacheCellStyle(gridRow, gridCol, { alignment: ALIGN.LEFT_CENTER });
      this.autoAligned.delete(key);
      this.grid.invalidate();
    }
  }

  // ── Style helpers ────────────────────────────────────────

  private cacheCellStyle(gridRow: number, gridCol: number, patch: CellStyleFields): void {
    const key = `${gridRow}:${gridCol}`;
    const prev = this.cellStyleCache.get(key) ?? {};
    this.cellStyleCache.set(key, { ...prev, ...patch });
  }

  private getCachedCellStyle(gridRow: number, gridCol: number): CellStyleFields {
    return this.cellStyleCache.get(`${gridRow}:${gridCol}`) ?? {};
  }

  private sanitizeStyle(style: CellStyleFields): CellStyleFields {
    const out: CellStyleFields = {};
    for (const [k, v] of Object.entries(style)) {
      if (v !== undefined) {
        (out as any)[k] = v;
      }
    }
    return out;
  }

  private styleEquals(a: CellStyleFields, b: CellStyleFields): boolean {
    const keys = new Set<string>([...Object.keys(a), ...Object.keys(b)]);
    for (const key of keys) {
      if ((a as any)[key] !== (b as any)[key]) {
        return false;
      }
    }
    return true;
  }

  private defaultAlignmentForCell(gridRow: number, gridCol: number): number {
    if (gridRow < 0 || gridCol < 0) {
      return ALIGN.CENTER_CENTER;
    }
    return ALIGN.LEFT_CENTER;
  }

  private defaultForeColorForCell(gridRow: number, gridCol: number): number {
    if (gridRow < 0 || gridCol < 0) {
      return SHEET_COLORS.headerFg;
    }
    return SHEET_COLORS.black;
  }

  private defaultBackColorForCell(gridRow: number, gridCol: number): number {
    if (gridRow < 0 || gridCol < 0) {
      return SHEET_COLORS.headerBg;
    }
    return SHEET_COLORS.white;
  }

  private resolveOldStyleForPatch(gridRow: number, gridCol: number, patch: CellStyleFields): CellStyleFields {
    const old: CellStyleFields = { ...this.getCachedCellStyle(gridRow, gridCol) };

    const boolKeys: Array<keyof CellStyleFields> = [
      "fontBold", "fontItalic", "fontUnderline", "fontStrikethrough",
    ];
    for (const key of boolKeys) {
      if (patch[key] != null && old[key] == null) {
        (old as any)[key] = false;
      }
    }

    const borderKeys: Array<keyof CellStyleFields> = [
      "borderTop", "borderRight", "borderBottom", "borderLeft",
    ];
    for (const key of borderKeys) {
      if (patch[key] != null && old[key] == null) {
        (old as any)[key] = 0;
      }
    }

    const borderColorKeys: Array<keyof CellStyleFields> = [
      "borderTopColor", "borderRightColor", "borderBottomColor", "borderLeftColor",
    ];
    for (const key of borderColorKeys) {
      if (patch[key] != null && old[key] == null) {
        (old as any)[key] = SHEET_COLORS.black;
      }
    }

    if (patch.alignment != null && old.alignment == null) {
      old.alignment =
        this.cellAlignments.get(`${gridRow}:${gridCol}`)
        ?? this.defaultAlignmentForCell(gridRow, gridCol);
    }
    if (patch.foreColor != null && old.foreColor == null) {
      old.foreColor = this.defaultForeColorForCell(gridRow, gridCol);
    }
    if (patch.backColor != null && old.backColor == null) {
      old.backColor = this.defaultBackColorForCell(gridRow, gridCol);
    }
    if (patch.fontName != null && old.fontName == null) {
      old.fontName = this.defaultFontName;
    }
    if (patch.fontSize != null && old.fontSize == null) {
      old.fontSize = this.defaultFontSize;
    }

    return this.sanitizeStyle(old);
  }

  private applyStyleUpdates(updates: Array<{ row: number; col: number; style: CellStyleFields }>): void {
    const sanitized = updates
      .map((u) => ({ row: u.row, col: u.col, style: this.sanitizeStyle(u.style) }))
      .filter((u) => Object.keys(u.style).length > 0);
    if (sanitized.length === 0) return;

    this.store.batchUpdateCells(
      sanitized.map((u) => ({ row: u.row, col: u.col, style: this.toEngineStyle(u.style) })),
    );
    // Force repaint — WASM is_dirty may lag a frame
    this.grid.invalidate();
    for (const u of sanitized) {
      this.cacheCellStyle(u.row, u.col, u.style);
      if (typeof u.style.alignment === "number") {
        this.cacheAlignment(u.row, u.col, u.style.alignment);
        this.autoAligned.delete(`${u.row}:${u.col}`);
      }
    }
  }

  private executeStylePatches(
    patches: Array<{ row: number; col: number; patch: CellStyleFields }>,
  ): void {
    const cells: Array<{ row: number; col: number }> = [];
    const oldStyles: CellStyleFields[] = [];
    const newStyles: CellStyleFields[] = [];

    for (const p of patches) {
      const patch = this.sanitizeStyle(p.patch);
      if (Object.keys(patch).length === 0) continue;

      const oldStyle = this.resolveOldStyleForPatch(p.row, p.col, patch);
      const nextStyle = this.sanitizeStyle({ ...oldStyle, ...patch });
      if (this.styleEquals(oldStyle, nextStyle)) continue;

      cells.push({ row: p.row, col: p.col });
      oldStyles.push(oldStyle);
      newStyles.push(nextStyle);
    }

    if (cells.length === 0) return;

    this.undoStack.execute(
      new CellStyleChange(
        (updates) => this.applyStyleUpdates(updates),
        cells,
        oldStyles,
        newStyles,
      ),
    );
  }

  private clampDataRange(range: CellRange): CellRange | null {
    const maxRow = this.grid.rowCount - 0 - 1;
    const maxCol = this.grid.colCount - 0 - 1;
    if (maxRow < 0 || maxCol < 0) return null;

    const row1 = Math.max(0, Math.min(range.row1, range.row2));
    const col1 = Math.max(0, Math.min(range.col1, range.col2));
    const row2 = Math.min(maxRow, Math.max(range.row1, range.row2));
    const col2 = Math.min(maxCol, Math.max(range.col1, range.col2));
    if (row1 > row2 || col1 > col2) return null;
    return { row1, col1, row2, col2 };
  }

  private toggleStyle(prop: keyof CellStyleFields): void {
    const range = this.clampDataRange(this.selection.getRange());
    if (!range) return;
    const rowOffset = 0;
    const colOffset = 0;

    let allOn = true;
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const gr = r + rowOffset;
        const gc = c + colOffset;
        if (this.getCachedCellStyle(gr, gc)[prop] !== true) {
          allOn = false;
          break;
        }
      }
      if (!allOn) break;
    }

    const nextValue = !allOn;
    const patches: Array<{ row: number; col: number; patch: CellStyleFields }> = [];
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const gr = r + rowOffset;
        const gc = c + colOffset;
        patches.push({ row: gr, col: gc, patch: { [prop]: nextValue } as CellStyleFields });
      }
    }
    this.executeStylePatches(patches);
  }

  private resolveResponsiveScale(width: number): number {
    const coarsePointer = typeof window.matchMedia === "function"
      && (window.matchMedia("(pointer: coarse)").matches || window.matchMedia("(hover: none)").matches);
    if (width <= 480) {
      return coarsePointer ? 1.22 : 1.12;
    }
    if (width <= 768) {
      return coarsePointer ? 1.16 : 1.08;
    }
    if (coarsePointer && width <= 920) {
      return 1.08;
    }
    return 1;
  }

  private applyResponsiveLayout(
    force = false,
    options: { skipOverrideRescale?: boolean } = {},
  ): void {
    const width = Math.max(
      1,
      Math.round(this.rootEl.clientWidth || this.container.clientWidth || window.innerWidth || 1),
    );
    const nextScale = this.resolveResponsiveScale(width);
    const combinedScale = nextScale * this.userZoomScale;
    const nextLayoutPixelScale = combinedScale * this.currentDeviceScale();
    if (
      !force
      && Math.abs(nextScale - this.responsiveScale) < 0.01
      && Math.abs(nextLayoutPixelScale - this.layoutPixelScale) < 0.01
    ) {
      return;
    }

    const previousLayoutPixelScale = this.layoutPixelScale > 0 ? this.layoutPixelScale : 1;
    const relativeLayoutScale = nextLayoutPixelScale / previousLayoutPixelScale;
    this.responsiveScale = nextScale;
    this.layoutPixelScale = nextLayoutPixelScale;
    this.rootEl.classList.toggle("vx-compact", nextScale > 1.01);

    const scaledFontSize = Math.round(this.defaultFontSize * combinedScale * 10) / 10;
    const scaledRowHeightCss = Math.max(
      this.baseDefaultRowHeight * combinedScale,
      this.minimumRowHeightForFont(scaledFontSize) + 4,
    );
    const scaledColumnHeaderHeightCss = Math.max(
      scaledRowHeightCss,
      this.baseColumnHeaderHeight * combinedScale,
    );
    const scaledColWidthCss = Math.max(1, this.baseDefaultColWidth * combinedScale);
    const scaledRowIndicatorWidthCss = Math.max(24, this.baseRowIndicatorStartWidth * combinedScale);

    this.grid.setFontSize(this.toEngineFontSize(scaledFontSize));
    this.grid.defaultRowHeight = this.toLayoutPixels(scaledRowHeightCss);
    this.grid.defaultColWidth = this.toLayoutPixels(scaledColWidthCss);
    this.setColumnHeaderHeight(this.toLayoutPixels(scaledColumnHeaderHeightCss));
    this.grid.rowIndicatorStartWidth = this.toLayoutPixels(scaledRowIndicatorWidthCss);
    if (!options.skipOverrideRescale
      && typeof this.wasm.scale_row_height_overrides === "function"
      && Number.isFinite(relativeLayoutScale)
      && relativeLayoutScale > 0
      && Math.abs(relativeLayoutScale - 1.0) > 0.01) {
      this.wasm.scale_row_height_overrides(this.grid.id, relativeLayoutScale);
    }
    if (!options.skipOverrideRescale
      && typeof this.wasm.scale_col_width_overrides === "function"
      && Number.isFinite(relativeLayoutScale)
      && relativeLayoutScale > 0
      && Math.abs(relativeLayoutScale - 1.0) > 0.01) {
      this.wasm.scale_col_width_overrides(this.grid.id, relativeLayoutScale);
    }
    this.grid.invalidate();
  }

  private clampZoomScale(scale: number): number {
    if (!Number.isFinite(scale) || scale <= 0) {
      return 1;
    }
    return Math.max(
      VolvoxSheet.MIN_ZOOM_SCALE,
      Math.min(VolvoxSheet.MAX_ZOOM_SCALE, scale),
    );
  }

  private applyUserZoomScale(
    scale: number,
    options: { skipOverrideRescale?: boolean; force?: boolean } = {},
  ): void {
    const nextZoomScale = this.clampZoomScale(scale);
    const hitZoomLimit = Math.abs(nextZoomScale - scale) > VolvoxSheet.ZOOM_SCALE_EPSILON;
    this.statusBar?.setZoom(nextZoomScale * 100);
    if (!options.force
      && !hitZoomLimit
      && Math.abs(nextZoomScale - this.userZoomScale) <= VolvoxSheet.ZOOM_SCALE_EPSILON) {
      return;
    }
    this.userZoomScale = nextZoomScale;
    this.applyResponsiveLayout(true, options);
  }

  private snapPinchZoomScale(scale: number): number {
    const clampedScale = this.clampZoomScale(scale);
    if (Math.abs(clampedScale - 1) <= VolvoxSheet.PINCH_SNAP_TO_ONE_EPSILON) {
      return 1;
    }
    return clampedScale;
  }

  private getEffectiveFontSize(gridRow: number, gridCol: number): number {
    const fontSize = this.getCachedCellStyle(gridRow, gridCol).fontSize;
    if (typeof fontSize === "number" && Number.isFinite(fontSize) && fontSize > 0) {
      return fontSize;
    }
    return this.defaultFontSize;
  }

  private minimumRowHeightForFont(fontSize: number): number {
    const cssPx = this.toCssFontSizePx(fontSize);
    return Math.ceil(
      cssPx * VolvoxSheet.FONT_LINE_HEIGHT_MULTIPLIER + VolvoxSheet.FONT_ROW_PADDING_PX,
    );
  }

  private currentDeviceScale(): number {
    return Number.isFinite(window.devicePixelRatio) && window.devicePixelRatio > 0
      ? window.devicePixelRatio
      : 1;
  }

  private toLayoutPixels(cssPx: number): number {
    return Math.max(1, Math.round(cssPx * this.currentDeviceScale()));
  }

  private setColumnHeaderHeight(heightPx: number): void {
    const normalizedHeight = Math.max(1, Math.round(heightPx));
    this.currentColumnHeaderHeight = normalizedHeight;
    if (typeof this.wasm.set_col_indicator_top_default_row_height === "function") {
      this.wasm.set_col_indicator_top_default_row_height(this.grid.id, normalizedHeight);
    }
  }

  private toCssFontSizePx(pointSizePt: number): number {
    return pointSizePt * VolvoxSheet.SHEET_PT_TO_CSS_PX;
  }

  private toEngineFontSize(pointSizePt: number): number {
    const dpr = this.currentDeviceScale();
    return this.toCssFontSizePx(pointSizePt) * dpr;
  }

  private toEngineStyle(style: CellStyleFields): CellStyleFields {
    if (typeof style.fontSize !== "number" || !Number.isFinite(style.fontSize) || style.fontSize <= 0) {
      return style;
    }
    return { ...style, fontSize: this.toEngineFontSize(style.fontSize) };
  }

  private stepFontSize(current: number, direction: 1 | -1): number {
    const steps = VolvoxSheet.SHEET_FONT_SIZE_STEPS;
    if (direction > 0) {
      for (const step of steps) {
        if (step > current) return step;
      }
      return steps[steps.length - 1];
    }
    for (let i = steps.length - 1; i >= 0; i--) {
      if (steps[i] < current) return steps[i];
    }
    return steps[0];
  }

  private adjustSelectionFontSize(direction: 1 | -1): void {

    const range = this.clampDataRange(this.selection.getRange());
    if (!range) return;

    const rowOffset = 0;
    const colOffset = 0;
    const patches: Array<{ row: number; col: number; patch: CellStyleFields }> = [];
    const rowMinHeights = new Map<number, number>();

    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const gridRow = r + rowOffset;
        const gridCol = c + colOffset;
        const current = this.getEffectiveFontSize(gridRow, gridCol);
        const next = this.stepFontSize(current, direction);
        if (next === current) continue;

        patches.push({ row: gridRow, col: gridCol, patch: { fontSize: next } });
        if (direction > 0) {
          const required = this.minimumRowHeightForFont(next);
          const prev = rowMinHeights.get(gridRow) ?? 0;
          if (required > prev) {
            rowMinHeights.set(gridRow, required);
          }
        }
      }
    }

    if (patches.length === 0) return;
    this.executeStylePatches(patches);

    // Match Sheet behavior: increasing font can auto-grow row height,
    // but does not auto-grow column width.
    for (const [gridRow, required] of rowMinHeights) {
      const currentHeight = this.grid.getRowHeight(gridRow);
      if (currentHeight < required) {
        this.grid.setRowHeight(gridRow, required);
      }
    }
  }

  // ── Merge-aware navigation ──────────────────────────────

  /**
   * Move selection by (dRow, dCol), jumping past merged regions.
   *
   * _preMergeRow/_preMergeCol always track the unresolved target — the
   * position the user "would" be at if merges didn't exist.  When the
   * current cell is inside a merge, the cross-axis comes from these
   * saved values so the user doesn't lose their row/col context.
   */
  private moveSelectionMergeAware(dRow: number, dCol: number): void {
    const gridRow = this.selection.row;
    const gridCol = this.selection.col;
    const rowOffset = 0;
    const colOffset = 0;

    // Find the merged region containing the current cell (grid-space)
    const regions = this.grid.getMergedRegions();
    let merge: { row1: number; col1: number; row2: number; col2: number } | null = null;
    for (const r of regions) {
      if (gridRow >= r.row1 && gridRow <= r.row2 && gridCol >= r.col1 && gridCol <= r.col2) {
        merge = r;
        break;
      }
    }

    let targetRow: number;
    let targetCol: number;

    if (merge) {
      // Jump from the edge of the merged region, restoring the
      // cross-axis from the pre-merge position.
      if (dCol > 0) {
        targetRow = this._preMergeRow;
        targetCol = merge.col2 + 1;
      } else if (dCol < 0) {
        targetRow = this._preMergeRow;
        targetCol = merge.col1 - 1;
      } else if (dRow > 0) {
        targetRow = merge.row2 + 1;
        targetCol = this._preMergeCol;
      } else {
        targetRow = merge.row1 - 1;
        targetCol = this._preMergeCol;
      }
    } else {
      targetRow = gridRow + dRow;
      targetCol = gridCol + dCol;
    }

    // Clamp to grid bounds (data area)
    targetRow = Math.max(rowOffset, Math.min(this.grid.rowCount - 1, targetRow));
    targetCol = Math.max(colOffset, Math.min(this.grid.colCount - 1, targetCol));

    // Always save the unresolved target as the pre-merge position.
    // This tracks where the user "would be" without merges.
    this._preMergeRow = targetRow;
    this._preMergeCol = targetCol;

    // If the target lands inside a merge, snap to its master cell
    const master = this.resolveMergedMaster(targetRow, targetCol);
    this.selection.select(master.row, master.col);
  }

  // ── Navigation ───────────────────────────────────────────

  private navigateToDataCell(dataRow: number, dataCol: number): void {
    const gridRow = dataRow + 0;
    const gridCol = dataCol + 0;
    if (gridRow >= 0 && gridRow < this.grid.rowCount
      && gridCol >= 0 && gridCol < this.grid.colCount) {
      this.selection.select(gridRow, gridCol);
      this.onSelectionUpdated();
      this.canvas.focus();
    }
  }

  private onSelectionUpdated(): void {
    this.ensureActiveCellExplicitNonBold();
    this.formulaBar?.onSelectionChanged();
    this.highlightHeaders();
    this.updateStatusBar();
  }

  private ensureActiveCellExplicitNonBold(): void {
    const gridRow = this.selection.row;
    const gridCol = this.selection.col;
    if (gridRow < 0 || gridCol < 0) return;

    const cached = this.getCachedCellStyle(gridRow, gridCol);
    if (cached.fontBold === true || cached.fontBold === false) return;

    // Guard against runtime defaults/styles making selected non-bold cells
    // appear bold. Keep bold cells unchanged.
    this.store.batchUpdateCells([{ row: gridRow, col: gridCol, style: { fontBold: false } }]);
    this.cacheCellStyle(gridRow, gridCol, { fontBold: false });
    this.grid.invalidate();
  }

  /** Sync toolbar undo/redo button state. */
  private updateToolbarState(): void {
    this.toolbar?.updateUndoRedoState(
      this.undoStack.canUndo,
      this.undoStack.canRedo,
    );
  }

  /** Sync formula bar and status bar with current edit state. */
  private updateEditModeUI(isEditing: boolean): void {
    this.formulaBar?.setEditing(isEditing);
    this.statusBar?.setMode(isEditing ? "Edit" : "Ready");
    if (isEditing) {
      this.syncFormulaHighlightsFromText();
    } else {
      this.clearFormulaHighlights();
    }
  }

  private updateStatusBar(): void {
    if (!this.statusBar) return;
    const range = this.selection.getRange();
    // Only show aggregates for multi-cell selection or if a single cell has a numeric value
    const isSingle = range.row1 === range.row2 && range.col1 === range.col2;
    if (isSingle) {
      const val = this.store.getCellValue(range.row1, range.col1);
      if (!val || !VolvoxSheet.NUMERIC_RE.test(val.trim())) {
        this.statusBar.clear();
        return;
      }
    }

    // Compute aggregates from shadow data
    let sum = 0;
    let count = 0;
    let numericCount = 0;
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const v = this.store.getCellValue(r, c);
        if (v !== "") {
          count++;
          const n = Number(v);
          if (Number.isFinite(n)) {
            sum += n;
            numericCount++;
          }
        }
      }
    }
    const avg = numericCount > 0 ? sum / numericCount : 0;
    this.statusBar.update({ sum, avg, count });
  }

  // ── Header styling ───────────────────────────────────────

  private applyHeaderStyles(): void {
    this.grid.showColumnHeaders = true;
    this.grid.columnIndicatorTopRowCount = 1;
    this.setColumnHeaderHeight(this.currentColumnHeaderHeight);
    this.grid.showRowIndicator = true;
    this.grid.rowIndicatorStartModeBits = SHEET_ROW_INDICATOR_MODE;
    this.grid.rowIndicatorStartWidth = this.toLayoutPixels(
      Math.max(24, this.baseRowIndicatorStartWidth * this.responsiveScale * this.userZoomScale),
    );
    this.applyIndicatorTheme();
    this.grid.invalidate();
  }

  private applyIndicatorTheme(): void {
    if (typeof this.wasm.volvox_grid_configure !== "function") {
      return;
    }
    try {
      const configBytes = encodeGridConfig({
        indicators: {
          rowStart: {
            visible: true,
            background: SHEET_COLORS.headerBg,
            foreground: SHEET_COLORS.headerFg,
            gridLines: 1,
            gridColor: SHEET_COLORS.headerBorder,
            allowResize: true,
          },
          colTop: {
            visible: true,
            bandRows: 1,
            defaultRowHeight: this.currentColumnHeaderHeight,
            background: SHEET_COLORS.headerBg,
            foreground: SHEET_COLORS.headerFg,
            gridLines: 1,
            gridColor: SHEET_COLORS.headerBorder,
            allowResize: true,
          },
          cornerTopStart: {
            visible: true,
            background: SHEET_COLORS.headerCornerBg,
            foreground: SHEET_COLORS.headerFg,
          },
        },
      });
      this.wasm.volvox_grid_configure(BigInt(this.grid.id), configBytes);
    } catch (_) {}
  }

  // ── Header highlight on selection ────────────────────────

  private highlightHeaders(): void {
    // Indicator-band header highlights now come from engine selection/hover rendering.
  }

  // ── Event polling ────────────────────────────────────────

  private startEventPoll(): void {
    const poll = () => {
      if (this.destroyed) return;
      this.drainEvents();
      this.eventPollTimer = requestAnimationFrame(poll);
    };
    this.eventPollTimer = requestAnimationFrame(poll);
  }

  private drainEvents(): void {
    try {
      const events = this.grid.drainEventStreamRaw(64);
      for (const raw of events) {
        const envelope = decodeGridEventEnvelope(raw);
        if (!envelope) continue;
        this.handleEvent(envelope.eventField, envelope.payload);
      }
      // Poll engine selection state every frame — the engine updates
      // row_end/col_end silently during drag, shift+click, and shift+arrow
      // without firing SelectionChanged events.
      this.syncSelectionFromEngine();
    } catch {
      // A WASM panic (e.g. RefCell already borrowed) converts to a JS error.
      // Swallow it so the rAF poll loop stays alive.
    }
  }

  /** Read the engine's authoritative selection and sync the JS model. */
  private syncSelectionFromEngine(): void {
    const selection = this.grid.getSelection();
    if (!this.selection.matchesSnapshot(selection)) {
      // Selection changed outside moveSelectionMergeAware (e.g. mouse click).
      // Update pre-merge tracking so header highlights and future arrow
      // navigation use the correct position.
      this._preMergeRow = selection.row;
      this._preMergeCol = selection.col;
      this.selection.syncFromSnapshot(selection);
      this.onSelectionUpdated();
    }
  }

  private handleEvent(field: number, payload: Uint8Array): void {
    switch (field) {
      case EVENT_ENTER_CELL:
      case EVENT_CELL_FOCUS_CHANGED: {
        const { row, col } = decodeCellFocusPayload(payload);
        this.lastClickedCell = `${row}:${col}`;
        this.selection.onSelectionChanged(row, col);
        this.onSelectionUpdated();
        break;
      }
      case EVENT_SELECTION_CHANGED: {
        const sel = decodeSelectionChangedPayload(payload);
        this.selection.onSelectionEndChanged(sel.rowEnd, sel.colEnd);
        this.onSelectionUpdated();
        break;
      }
      case EVENT_START_EDIT: {
        const { row, col } = decodeCellFocusPayload(payload);
        this.editState.onEngineStartEdit(row, col);
        if (this.gridEditInput) {
          this.editState.onEditTextChanged(this.gridEditInput.value);
        }
        this.updateEditModeUI(true);
        requestAnimationFrame(() => {
          this.syncEditInputAlign();
          this.syncHostEditSelectionFromEngine();
        });
        const dataRow = row - 0;
        const dataCol = col - 0;
        if (dataRow >= 0 && dataCol >= 0) {
          const key = `${dataRow}:${dataCol}`;
          this.pendingEditOriginalRaw.set(
            key,
            this.store.getCellRawValue(dataRow, dataCol),
          );
        }
        break;
      }
      case EVENT_AFTER_EDIT: {
        const { row, col, oldText: _oldText, newText } = decodeAfterEditPayload(payload);
        this.editState.onEngineAfterEdit(row, col, _oldText, newText);
        const rowOffset = 0;
        const colOffset = 0;
        const dataRow = row - rowOffset;
        const dataCol = col - colOffset;
        if (dataRow >= 0 && dataCol >= 0) {
          const key = `${dataRow}:${dataCol}`;
          const oldRaw =
            this.pendingEditOriginalRaw.get(key)
            ?? this.store.getCellRawValue(dataRow, dataCol);
          this.pendingEditOriginalRaw.delete(key);

          this.store.onCellEdited(dataRow, dataCol, newText);
          if (oldRaw !== newText) {
            this.undoStack.pushExecuted(
              new CellValueChange(this.store, dataRow, dataCol, oldRaw, newText),
            );
            this.autoAlignCell(dataRow, dataCol, this.store.getCellValue(dataRow, dataCol));
          }
        }
        this.formulaBar?.updateFormulaInput();
        this.updateEditModeUI(false);
        this.updateToolbarState();
        break;
      }
      case EVENT_CELL_EDIT_CHANGE: {
        const { text } = decodeCellEditChangePayload(payload);
        this.editState.onEditTextChanged(text);
        this.formulaBar?.onEditTextChanged(text);
        this.syncFormulaHighlightsFromText(text);
        break;
      }
    }
  }

  // ── Context menu ─────────────────────────────────────────

  private onContextMenu = (e: MouseEvent): void => {
    e.preventDefault();
    const mouseRow = typeof this.wasm.get_mouse_row === "function"
      ? Number(this.wasm.get_mouse_row(this.grid.id))
      : this.selection.row;
    const mouseCol = typeof this.wasm.get_mouse_col === "function"
      ? Number(this.wasm.get_mouse_col(this.grid.id))
      : this.selection.col;

    const scope = this.resolveContextMenuScope(e, mouseRow, mouseCol);
    this.contextMenuScope = scope;
    this.applyContextMenuSelection(mouseRow, mouseCol, scope);
    this.contextMenu.show(e.clientX, e.clientY, scope);
  };

  private resolveContextMenuScope(
    e: MouseEvent,
    row: number,
    col: number,
  ): ContextMenuScope {
    return this.resolvePointerScope(e, row, col);
  }

  private applyContextMenuSelection(row: number, col: number, scope: ContextMenuScope): void {
    const maxGridRow = this.grid.rowCount - 1;
    const maxGridCol = this.grid.colCount - 1;
    const firstDataRow = 0;
    const firstDataCol = 0;
    if (maxGridRow < firstDataRow || maxGridCol < firstDataCol) return;

    if (scope === "rowHeader") {
      const targetRow = Math.max(firstDataRow, Math.min(maxGridRow, row));
      this.selection.select(targetRow, firstDataCol, targetRow, maxGridCol);
      this.onSelectionUpdated();
      return;
    }
    if (scope === "colHeader") {
      const targetCol = Math.max(firstDataCol, Math.min(maxGridCol, col));
      this.selection.select(firstDataRow, targetCol, maxGridRow, targetCol);
      this.onSelectionUpdated();
      return;
    }
    if (scope === "corner") {
      this.selection.select(firstDataRow, firstDataCol, maxGridRow, maxGridCol);
      this.onSelectionUpdated();
      return;
    }
    if (scope === "cell") {
      const targetRow = Math.max(firstDataRow, Math.min(maxGridRow, row));
      const targetCol = Math.max(firstDataCol, Math.min(maxGridCol, col));
      // If the right-clicked cell is inside the current selection, keep it.
      const r1 = Math.min(this.selection.row, this.selection.rowEnd);
      const r2 = Math.max(this.selection.row, this.selection.rowEnd);
      const c1 = Math.min(this.selection.col, this.selection.colEnd);
      const c2 = Math.max(this.selection.col, this.selection.colEnd);
      if (targetRow >= r1 && targetRow <= r2 && targetCol >= c1 && targetCol <= c2) {
        return; // preserve existing multi-cell selection
      }
      this.selection.select(targetRow, targetCol);
      this.onSelectionUpdated();
    }
  }

  private handleContextMenuAction(action: ContextMenuAction): void {
    const hasDataRow = this.selection.dataRow >= 0;
    const hasDataCol = this.selection.dataCol >= 0;
    const range = this.selection.getRange();
    const hasDataRange = range.row1 >= 0 && range.col1 >= 0;

    switch (action) {
      case "cut": this.cut(); break;
      case "copy": this.copy(); break;
      case "paste": this.paste(); break;
      case "clearCell":
        if (hasDataRange) this.clearSelectedCells();
        break;
      case "insertRowAbove":
        if (hasDataRow) this.insertRows(this.selection.dataRow, 1);
        break;
      case "insertRowBelow":
        if (hasDataRow) this.insertRows(this.selection.dataRow + 1, 1);
        break;
      case "deleteRow":
        if (hasDataRow) this.deleteRows(this.selection.dataRow, 1);
        break;
      case "insertColumnLeft":
        if (hasDataCol) this.insertColumns(this.selection.dataCol, 1);
        break;
      case "insertColumnRight":
        if (hasDataCol) this.insertColumns(this.selection.dataCol + 1, 1);
        break;
      case "deleteColumn":
        if (hasDataCol) this.deleteColumns(this.selection.dataCol, 1);
        break;
      case "mergeCells":
        if (hasDataRange) this.mergeCells(range);
        break;
      case "unmergeCells":
        if (hasDataRange) this.unmergeCells(range);
        break;
    }
  }

  // ── Toolbar ──────────────────────────────────────────────

  private handleToolbarAction(action: ToolbarAction): void {
    const range = this.selection.getRange();
    const hasDataRow = this.selection.dataRow >= 0;
    const hasDataCol = this.selection.dataCol >= 0;
    const hasDataRange = range.row1 >= 0 && range.col1 >= 0;

    switch (action) {
      case "undo": this.undoStack.undo(); this.updateToolbarState(); break;
      case "redo": this.undoStack.redo(); this.updateToolbarState(); break;
      case "fontSizeIncrease": this.adjustSelectionFontSize(1); break;
      case "fontSizeDecrease": this.adjustSelectionFontSize(-1); break;
      case "bold": this.toggleStyle("fontBold"); break;
      case "italic": this.toggleStyle("fontItalic"); break;
      case "underline": this.toggleStyle("fontUnderline"); break;
      case "strikethrough": this.toggleStyle("fontStrikethrough"); break;
      case "alignLeft": this.setRangeAlignment(ALIGN.LEFT_CENTER); break;
      case "alignCenter": this.setRangeAlignment(ALIGN.CENTER_CENTER); break;
      case "alignRight": this.setRangeAlignment(ALIGN.RIGHT_CENTER); break;
      case "alignTop": this.setRangeVerticalAlignment(0); break;
      case "alignMiddle": this.setRangeVerticalAlignment(1); break;
      case "alignBottom": this.setRangeVerticalAlignment(2); break;
      case "mergeCells": if (hasDataRange) this.mergeCells(range); break;
      case "unmergeCells": if (hasDataRange) this.unmergeCells(range); break;
      case "insertRow": if (hasDataRow) this.insertRows(this.selection.dataRow, 1); break;
      case "deleteRow": if (hasDataRow) this.deleteRows(this.selection.dataRow, 1); break;
      case "insertColumn": if (hasDataCol) this.insertColumns(this.selection.dataCol, 1); break;
      case "deleteColumn": if (hasDataCol) this.deleteColumns(this.selection.dataCol, 1); break;
      // Borders
      case "borderAll": this.setBorders("all"); break;
      case "borderNone": this.setBorders("none"); break;
      case "borderOutside": this.setBorders("outside"); break;
      case "borderBottom": this.setBorders("bottom"); break;
      case "borderThick": this.setBorders("thick"); break;
      // Number format
      case "formatGeneral": this.setSelectionFormat(""); break;
      case "formatNumber": this.setSelectionFormat("#,##0.00"); break;
      case "formatCurrency": this.setSelectionFormat("$#,##0.00"); break;
      case "formatPercent": this.setSelectionFormat("0.00%"); break;
      case "formatDate": this.setSelectionFormat("MM/DD/YYYY"); break;
      // Freeze
      case "freezeRow": this.freezeRows(1); break;
      case "freezeCol": this.freezeColumns(1); break;
      case "freezeBoth": this.freezeRows(1); this.freezeColumns(1); break;
      case "unfreeze": this.freezeRows(0); this.freezeColumns(0); break;
    }
    this.canvas.focus();
  }

  private cacheAlignment(gridRow: number, gridCol: number, alignment: number): void {
    this.cellAlignments.set(`${gridRow}:${gridCol}`, alignment);
  }

  private setRangeVerticalAlignment(valign: number): void {
    const range = this.clampDataRange(this.selection.getRange());
    if (!range) return;
    const rowOffset = 0;
    const colOffset = 0;
    const patches: Array<{ row: number; col: number; patch: CellStyleFields }> = [];
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const gr = r + rowOffset;
        const gc = c + colOffset;
        const currentAlign = this.getCachedCellStyle(gr, gc).alignment ?? ALIGN.LEFT_CENTER;
        const horizontal = Math.floor(currentAlign / 3);
        const alignment = horizontal * 3 + valign;
        patches.push({ row: gr, col: gc, patch: { alignment } });
      }
    }
    this.executeStylePatches(patches);
  }

  private setRangeAlignment(alignment: number): void {
    const range = this.clampDataRange(this.selection.getRange());
    if (!range) return;
    const rowOffset = 0;
    const colOffset = 0;
    const patches: Array<{ row: number; col: number; patch: CellStyleFields }> = [];
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const gr = r + rowOffset;
        const gc = c + colOffset;
        patches.push({ row: gr, col: gc, patch: { alignment } });
      }
    }
    this.executeStylePatches(patches);
  }

  // ── Border helpers (Phase D implements encoding) ─────────

  private setBorders(mode: "all" | "none" | "outside" | "bottom" | "thick"): void {
    const range = this.clampDataRange(this.selection.getRange());
    if (!range) return;
    const rowOffset = 0;
    const colOffset = 0;
    const patches: Array<{ row: number; col: number; patch: CellStyleFields }> = [];

    const THIN = 1;  // BorderStyle.BORDER_THIN
    const THICK = 3; // BorderStyle.BORDER_THICK
    const NONE = 0;  // BorderStyle.BORDER_NONE
    const borderColor = 0xff000000; // black

    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        const gr = r + rowOffset;
        const gc = c + colOffset;
        const style: CellStyleFields = {};

        if (mode === "none") {
          style.borderTop = NONE;
          style.borderRight = NONE;
          style.borderBottom = NONE;
          style.borderLeft = NONE;
        } else if (mode === "all") {
          style.borderTop = THIN;
          style.borderRight = THIN;
          style.borderBottom = THIN;
          style.borderLeft = THIN;
          style.borderTopColor = borderColor;
          style.borderRightColor = borderColor;
          style.borderBottomColor = borderColor;
          style.borderLeftColor = borderColor;
        } else if (mode === "outside") {
          if (r === range.row1) { style.borderTop = THIN; style.borderTopColor = borderColor; }
          if (r === range.row2) { style.borderBottom = THIN; style.borderBottomColor = borderColor; }
          if (c === range.col1) { style.borderLeft = THIN; style.borderLeftColor = borderColor; }
          if (c === range.col2) { style.borderRight = THIN; style.borderRightColor = borderColor; }
        } else if (mode === "bottom") {
          if (r === range.row2) { style.borderBottom = THIN; style.borderBottomColor = borderColor; }
        } else if (mode === "thick") {
          if (r === range.row1) { style.borderTop = THICK; style.borderTopColor = borderColor; }
          if (r === range.row2) { style.borderBottom = THICK; style.borderBottomColor = borderColor; }
          if (c === range.col1) { style.borderLeft = THICK; style.borderLeftColor = borderColor; }
          if (c === range.col2) { style.borderRight = THICK; style.borderRightColor = borderColor; }
        }

        if (Object.keys(style).length > 0) {
          patches.push({ row: gr, col: gc, patch: style });
        }
      }
    }
    this.executeStylePatches(patches);
  }

  // ══════════════════════════════════════════════════════════
  // Public API (VolvoxSheetApi)
  // ══════════════════════════════════════════════════════════

  getCellValue(row: number, col: number): string {
    return this.store.getCellValue(row, col);
  }

  getCellRawValue(row: number, col: number): string {
    return this.store.getCellRawValue(row, col);
  }

  getCellFormula(row: number, col: number): string | null {
    return this.store.getCellFormula(row, col);
  }

  setCellValue(row: number, col: number, value: string): void {
    const old = this.store.getCellRawValue(row, col);
    if (old !== value) {
      const cmd = new CellValueChange(this.store, row, col, old, value);
      this.undoStack.execute(cmd);
      this.updateToolbarState();
    }
  }

  getData(): string[][] {
    return this.store.getData();
  }

  setData(data: string[][]): void {
    const before = this.store.getData();
    this.store.setData(data);
    const after = this.store.getData();
    if (this.dataEquals(before, after)) return;
    this.undoStack.pushExecuted(
      new SnapshotDataChange(
        (snapshot) => this.applyDataSnapshot(snapshot),
        before,
        after,
        "Set data",
      ),
    );
  }

  clearRange(range: CellRange): void {
    const maxRow = this.grid.rowCount - 0 - 1;
    const maxCol = this.grid.colCount - 0 - 1;
    if (maxRow < 0 || maxCol < 0) return;

    const row1 = Math.max(0, Math.min(range.row1, range.row2));
    const col1 = Math.max(0, Math.min(range.col1, range.col2));
    const row2 = Math.min(maxRow, Math.max(range.row1, range.row2));
    const col2 = Math.min(maxCol, Math.max(range.col1, range.col2));
    if (row1 > row2 || col1 > col2) return;

    const commands: CellValueChange[] = [];
    for (let r = row1; r <= row2; r++) {
      for (let c = col1; c <= col2; c++) {
        const old = this.store.getCellRawValue(r, c);
        if (old !== "") {
          commands.push(new CellValueChange(this.store, r, c, old, ""));
        }
      }
    }
    if (commands.length === 1) {
      this.undoStack.execute(commands[0]);
    } else if (commands.length > 1) {
      this.undoStack.execute(new BatchCommand(commands, "Clear range"));
    }
  }

  getSelection(): CellRange {
    return this.selection.getRange();
  }

  setSelection(range: CellRange): void {
    this.selection.setFromDataRange(range);
    this.onSelectionUpdated();
  }

  getActiveCell(): CellRef {
    return this.selection.getActiveCell();
  }

  setCellStyle(row: number, col: number, style: CellStyleUpdate): void {
    const maxRow = this.grid.rowCount - 0 - 1;
    const maxCol = this.grid.colCount - 0 - 1;
    if (row < 0 || col < 0 || row > maxRow || col > maxCol) return;

    const gridRow = row + 0;
    const gridCol = col + 0;
    const mapped: CellStyleFields = this.mapStyleUpdate(style);
    this.executeStylePatches([{ row: gridRow, col: gridCol, patch: mapped }]);
  }

  setRangeStyle(range: CellRange, style: CellStyleUpdate): void {
    const clamped = this.clampDataRange(range);
    if (!clamped) return;
    const rowOffset = 0;
    const colOffset = 0;
    const mapped: CellStyleFields = this.mapStyleUpdate(style);
    const patches: Array<{ row: number; col: number; patch: CellStyleFields }> = [];
    for (let r = clamped.row1; r <= clamped.row2; r++) {
      for (let c = clamped.col1; c <= clamped.col2; c++) {
        const gr = r + rowOffset;
        const gc = c + colOffset;
        patches.push({ row: gr, col: gc, patch: mapped });
      }
    }
    this.executeStylePatches(patches);
  }

  private mapStyleUpdate(style: CellStyleUpdate): CellStyleFields {
    const mapped: CellStyleFields = {
      fontBold: style.bold,
      fontItalic: style.italic,
      fontUnderline: style.underline,
      fontStrikethrough: style.strikethrough,
      fontName: style.fontName,
      fontSize: style.fontSize,
      foreColor: style.foreColor,
      backColor: style.backColor,
      alignment: style.alignment,
      borderTop: style.borderTop,
      borderRight: style.borderRight,
      borderBottom: style.borderBottom,
      borderLeft: style.borderLeft,
    };
    if (style.borderColor != null) {
      mapped.borderTopColor = style.borderColor;
      mapped.borderRightColor = style.borderColor;
      mapped.borderBottomColor = style.borderColor;
      mapped.borderLeftColor = style.borderColor;
    }
    return this.sanitizeStyle(mapped);
  }

  private dataEquals(a: string[][], b: string[][]): boolean {
    if (a.length !== b.length) return false;
    for (let r = 0; r < a.length; r++) {
      if (a[r].length !== b[r].length) return false;
      for (let c = 0; c < a[r].length; c++) {
        if (a[r][c] !== b[r][c]) return false;
      }
    }
    return true;
  }

  private applyInsertRows(index: number, count: number): void {
    const gridIndex = index + 0;
    this.grid.insertRows(gridIndex, count);
    this.store.onRowsInserted(index, count);
    this.store.populateHeaders();
  }

  private applyDeleteRows(index: number, count: number): void {
    const gridIndex = index + 0;
    this.grid.removeRows(gridIndex, count);
    this.store.onRowsDeleted(index, count);
    this.store.populateHeaders();
  }

  private applyInsertColumns(index: number, count: number): void {
    this.store.onColsInserted(index, count);
    this.store.populateHeaders();
    this.applyHeaderStyles();
  }

  private applyDeleteColumns(index: number, count: number): void {
    this.store.onColsDeleted(index, count);
    this.store.populateHeaders();
    this.applyHeaderStyles();
  }

  private applyDataSnapshot(data: string[][]): void {
    const targetRows = Math.max(0, data.length);
    const currentRows = this.grid.rowCount - 0;
    if (targetRows > currentRows) {
      this.grid.insertRows(0 + currentRows, targetRows - currentRows);
    } else if (targetRows < currentRows) {
      this.grid.removeRows(0 + targetRows, currentRows - targetRows);
    }

    // Caches can become stale after structural replay.
    this.cellAlignments.clear();
    this.cellStyleCache.clear();
    this.autoAligned.clear();

    this.store.setData(data);
    this.store.populateHeaders();
    this.applyHeaderStyles();

    const row = Math.max(0, Math.min(this.selection.row, this.grid.rowCount - 1));
    const col = Math.max(0, Math.min(this.selection.col, this.grid.colCount - 1));
    this.selection.select(row, col);
    this.onSelectionUpdated();
  }

  insertRows(index: number, count: number = 1): void {
    const safeCount = Math.max(0, Math.trunc(count));
    if (safeCount <= 0) return;
    const dataRows = this.grid.rowCount - 0;
    const safeIndex = Math.max(0, Math.min(Math.trunc(index), dataRows));

    const before = this.store.getData();
    this.applyInsertRows(safeIndex, safeCount);
    const after = this.store.getData();
    if (this.dataEquals(before, after)) return;

    this.undoStack.pushExecuted(
      new SnapshotDataChange(
        (snapshot) => this.applyDataSnapshot(snapshot),
        before,
        after,
        `Insert ${safeCount} row${safeCount === 1 ? "" : "s"}`,
      ),
    );
  }

  deleteRows(index: number, count: number = 1): void {
    const dataRows = this.grid.rowCount - 0;
    if (dataRows <= 0) return;
    const safeIndex = Math.trunc(index);
    if (safeIndex < 0 || safeIndex >= dataRows) return;
    const safeCount = Math.min(Math.max(0, Math.trunc(count)), dataRows - safeIndex);
    if (safeCount <= 0) return;

    const before = this.store.getData();
    this.applyDeleteRows(safeIndex, safeCount);
    const after = this.store.getData();
    if (this.dataEquals(before, after)) return;

    this.undoStack.pushExecuted(
      new SnapshotDataChange(
        (snapshot) => this.applyDataSnapshot(snapshot),
        before,
        after,
        `Delete ${safeCount} row${safeCount === 1 ? "" : "s"}`,
      ),
    );
  }

  insertColumns(index: number, count: number = 1): void {
    const safeCount = Math.max(0, Math.trunc(count));
    if (safeCount <= 0) return;
    const dataCols = this.grid.colCount - 0;
    const safeIndex = Math.max(0, Math.min(Math.trunc(index), dataCols));

    const before = this.store.getData();
    this.applyInsertColumns(safeIndex, safeCount);
    const after = this.store.getData();
    if (this.dataEquals(before, after)) return;

    this.undoStack.pushExecuted(
      new SnapshotDataChange(
        (snapshot) => this.applyDataSnapshot(snapshot),
        before,
        after,
        `Insert ${safeCount} column${safeCount === 1 ? "" : "s"}`,
      ),
    );
  }

  deleteColumns(index: number, count: number = 1): void {
    const dataCols = this.grid.colCount - 0;
    if (dataCols <= 0) return;
    const safeIndex = Math.trunc(index);
    if (safeIndex < 0 || safeIndex >= dataCols) return;
    const safeCount = Math.min(Math.max(0, Math.trunc(count)), dataCols - safeIndex);
    if (safeCount <= 0) return;

    const before = this.store.getData();
    this.applyDeleteColumns(safeIndex, safeCount);
    const after = this.store.getData();
    if (this.dataEquals(before, after)) return;

    this.undoStack.pushExecuted(
      new SnapshotDataChange(
        (snapshot) => this.applyDataSnapshot(snapshot),
        before,
        after,
        `Delete ${safeCount} column${safeCount === 1 ? "" : "s"}`,
      ),
    );
  }

  setColumnWidth(col: number, width: number): void {
    this.grid.setColWidth(col + 0, width);

  }

  setRowHeight(row: number, height: number): void {
    this.grid.setRowHeight(row + 0, height);

  }

  mergeCells(range: CellRange): void {
    const rowOffset = 0;
    const colOffset = 0;
    // Clear slave cells (Sheet default: only master keeps its value).
    for (let r = range.row1; r <= range.row2; r++) {
      for (let c = range.col1; c <= range.col2; c++) {
        if (r === range.row1 && c === range.col1) continue;
        this.store.setCellValue(r, c, "");
      }
    }
    this.grid.mergeCells(
      range.row1 + rowOffset,
      range.col1 + colOffset,
      range.row2 + rowOffset,
      range.col2 + colOffset,
    );
    // Auto-center merged cell content (like spreadsheet defaults).
    this.executeStylePatches([{
      row: range.row1 + rowOffset,
      col: range.col1 + colOffset,
      patch: { alignment: ALIGN.CENTER_CENTER },
    }]);
  }

  unmergeCells(range: CellRange): void {
    const rowOffset = 0;
    const colOffset = 0;
    this.grid.unmergeCells(
      range.row1 + rowOffset,
      range.col1 + colOffset,
      range.row2 + rowOffset,
      range.col2 + colOffset,
    );
  }

  /**
   * If (gridRow, gridCol) is inside a merged region, return the master cell
   * (top-left corner) in grid coordinates.  Otherwise return the input cell.
   */
  private resolveMergedMaster(gridRow: number, gridCol: number): { row: number; col: number } {
    const regions = this.grid.getMergedRegions();
    for (const r of regions) {
      if (gridRow >= r.row1 && gridRow <= r.row2 && gridCol >= r.col1 && gridCol <= r.col2) {
        return { row: r.row1, col: r.col1 };
      }
    }
    return { row: gridRow, col: gridCol };
  }

  getMergedRegions(): CellRange[] {
    const rowOffset = 0;
    const colOffset = 0;
    return this.grid.getMergedRegions().map((r) => ({
      row1: r.row1 - rowOffset,
      col1: r.col1 - colOffset,
      row2: r.row2 - rowOffset,
      col2: r.col2 - colOffset,
    }));
  }

  setColumnFormat(col: number, format: string): void {
    const gridCol = col + 0;
    if (typeof this.wasm.set_col_format === "function") {
      this.wasm.set_col_format(this.grid.id, gridCol, format);
      this.grid.invalidate();
    }
  }

  private setSelectionFormat(format: string): void {
    const range = this.selection.getRange();
    const maxCol = this.grid.colCount - 0 - 1;
    const start = Math.max(0, Math.min(range.col1, range.col2));
    const end = Math.min(maxCol, Math.max(range.col1, range.col2));
    if (start > end) return;
    for (let c = start; c <= end; c++) {
      this.setColumnFormat(c, format);
    }
  }

  private syncFreezePolicy(): void {
    if (typeof this.wasm.set_freeze_policy === "function") {
      this.wasm.set_freeze_policy(
        this.grid.id,
        this.grid.frozenColCount > 0,
        this.grid.frozenRowCount > 0,
      );
    }
  }

  freezeRows(count: number): void {
    this.grid.frozenRowCount = Math.max(0, Math.trunc(count));
    this.syncFreezePolicy();
  }

  freezeColumns(count: number): void {
    this.grid.frozenColCount = Math.max(0, Math.trunc(count));
    this.syncFreezePolicy();
  }

  undo(): void {
    this.undoStack.undo();
    this.updateToolbarState();
  }

  redo(): void {
    this.undoStack.redo();
    this.updateToolbarState();
  }

  async copy(): Promise<void> {
    await this.clipboard.copy(this.selection.getRanges());
  }

  async cut(): Promise<void> {
    await this.clipboard.cut(this.selection.getRanges());
  }

  async paste(text?: string): Promise<void> {
    const cell = this.selection.getActiveCell();
    await this.clipboard.paste(cell.row, cell.col, text);

  }

  resize(): void {
    this.applyResponsiveLayout(true);
    this.grid.invalidate();
  }

  // ── Sheet tab helpers ───────────────────────────────────

  private saveSheetSnapshot(): SheetSnapshot {
    return {
      name: this.sheetTabs?.activeSheet.name ?? "Sheet1",
      data: this.store.getData(),
      selection: { row: this.selection.dataRow, col: this.selection.dataCol },
    };
  }

  private loadSheetSnapshot(snap: SheetSnapshot): void {
    this.store.setData(snap.data);
    this.selection.select(snap.selection.row, snap.selection.col);
    this.onSelectionUpdated();
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;

    if (this.eventPollTimer) {
      cancelAnimationFrame(this.eventPollTimer);
    }

    clearTimeout(this.singleClickTimer);
    this.canvas.removeEventListener("keydown", this.onKeyDown);
    this.canvas.removeEventListener("pointerdown", this.onPointerDown);
    this.canvas.removeEventListener("pointermove", this.onPointerMove);
    this.canvas.removeEventListener("pointerup", this.onPointerUp);
    this.canvas.removeEventListener("pointercancel", this.onPointerCancel);
    this.canvas.removeEventListener("dblclick", this.onDblClick);
    this.gridEditInput?.removeEventListener("keydown", this.onEditInputKeyDown, true);
    this.gridEditInput?.removeEventListener("focus", this.onEditInputFocus);
    this.gridEditInput?.removeEventListener("blur", this.onEditInputBlurCapture, true);
    this.canvas.removeEventListener("contextmenu", this.onContextMenu);

    this.formulaBar?.destroy();
    this.toolbar?.destroy();
    this.statusBar?.destroy();
    this.sheetTabs?.destroy();
    this.findBar?.destroy();
    this.fillHandle?.destroy();
    this.contextMenu.destroy();

    this.editState.reset();
    this.undoStack.clear();
    this.layoutResizeObserver?.disconnect();
    this.layoutResizeObserver = null;
    this.activeTouchPointers.clear();
    this.pinchBaseZoomScale = null;
    this.grid.onZoomChange = null;
    (this.grid as any).onCompositionEditStart = null;

    this.grid.destroy();
    this.rootEl.remove();
  }
}
