// VolvoxGridClient.swift
//
// Swift wrapper around the VolvoxGrid Rust engine. Mirrors the public
// surface of dotnet/src/common/Volvox/VolvoxClient.cs so app code reads
// the same way across .NET, Java, Flutter, and Swift.
//
// Backed by SynurangLite (vendored) + the generated VolvoxGridServiceFfiLite
// in Generated/volvoxgrid_lite.swift. Zero non-system dependencies.

import Foundation

/// Thin, type-safe facade over the VolvoxGrid FFI. Every method is
/// `async throws` because the engine treats every RPC as potentially
/// long-running and may return an `FfiError` payload.
///
/// Symbol resolution order — `init(libraryPath:)` tries each step until
/// one succeeds:
///   1. Explicit `libraryPath` argument, if provided.
///   2. `VOLVOXGRID_LIBRARY_PATH` environment variable.
///   3. `RTLD_DEFAULT` — symbols already in the host process image.
///      This is the iOS / static-XCFramework path; throws on macOS /
///      Linux when nothing is statically linked.
///
/// `close()` shuts down the underlying plugin host and cascades into
/// open render and event streams. Idempotent.
public final class VolvoxGridClient: Sendable {

    // MARK: - Construction

    private let host: PluginHost
    private let service: VolvoxGridServiceFfiLite

    /// Construct a client. The default form — `VolvoxGridClient()` — is
    /// what iOS apps use: the engine is statically linked into the
    /// host binary, symbols are resolved via `RTLD_DEFAULT`.
    ///
    /// Pass `libraryPath` to dlopen a specific `.dylib` / `.so` / `.dll`
    /// instead (typical macOS / Linux dev setup). Or set the
    /// `VOLVOXGRID_LIBRARY_PATH` env var, which is honored when no
    /// explicit path is given.
    public init(libraryPath: String? = nil) throws {
        let resolved = libraryPath
            ?? ProcessInfo.processInfo.environment["VOLVOXGRID_LIBRARY_PATH"]
        let host: PluginHost
        if let path = resolved, !path.isEmpty {
            host = try PluginHost.load(path: path)
        } else {
            host = try PluginHost.attachToProcess()
        }
        self.host = host
        self.service = VolvoxGridServiceFfiLite(host: host)
    }

    /// Shut down the plugin host and any open streams. Idempotent.
    public func close() async {
        await host.close()
    }

    // MARK: - Grid lifecycle

    public func createGrid(viewportWidth: Int32, viewportHeight: Int32, scale: Float) async throws -> Int64 {
        var req = CreateRequest()
        req.viewportWidth = viewportWidth
        req.viewportHeight = viewportHeight
        req.scale = scale
        let resp = try await service.create(req)
        return resp.gridId
    }

    public func destroyGrid(_ gridId: Int64) async throws {
        var req = DestroyRequest()
        req.gridId = gridId
        _ = try await service.destroy(req)
    }

    public func configureGrid(_ gridId: Int64, config: GridConfig) async throws {
        var req = ConfigureRequest()
        req.gridId = gridId
        req.config = config
        _ = try await service.configure(req)
    }

    /// Set the total column count without touching the rest of the layout.
    public func setColCount(_ gridId: Int64, cols: Int32) async throws {
        var layout = LayoutConfig()
        layout.cols = cols
        try await configureLayout(gridId, layout: layout)
    }

    /// Set the total row count without touching the rest of the layout.
    public func setRowCount(_ gridId: Int64, rows: Int32) async throws {
        var layout = LayoutConfig()
        layout.rows = rows
        try await configureLayout(gridId, layout: layout)
    }

    /// Freeze the top `count` rows. `count == 0` clears the freeze.
    public func setFrozenRowCount(_ gridId: Int64, count: Int32) async throws {
        var layout = LayoutConfig()
        layout.frozenRows = count
        try await configureLayout(gridId, layout: layout)
    }

    /// Freeze the leftmost `count` columns. `count == 0` clears the freeze.
    public func setFrozenColCount(_ gridId: Int64, count: Int32) async throws {
        var layout = LayoutConfig()
        layout.frozenCols = count
        try await configureLayout(gridId, layout: layout)
    }

    /// Apply a single Apple-system theme preset (Light / Dark / Amber / …).
    public func setThemePreset(_ gridId: Int64, preset: ThemePreset) async throws {
        var config = GridConfig()
        config.themePreset = preset
        try await configureGrid(gridId, config: config)
    }

    /// Show or hide the leading row-indicator band (the gutter that holds
    /// row numbers, the expander arrow, and so on).
    public func setShowRowIndicator(_ gridId: Int64, visible: Bool) async throws {
        var row = RowIndicatorConfig()
        row.visible = visible
        var indicators = IndicatorsConfig()
        indicators.rowStart = row
        try await configureIndicators(gridId, indicators: indicators)
    }

    /// Show or hide the column-header band along the top of the grid.
    public func setShowColumnHeaders(_ gridId: Int64, visible: Bool) async throws {
        var col = ColIndicatorConfig()
        col.visible = visible
        var indicators = IndicatorsConfig()
        indicators.colTop = col
        try await configureIndicators(gridId, indicators: indicators)
    }

    private func configureLayout(_ gridId: Int64, layout: LayoutConfig) async throws {
        var config = GridConfig()
        config.layout = layout
        try await configureGrid(gridId, config: config)
    }

    private func configureIndicators(_ gridId: Int64, indicators: IndicatorsConfig) async throws {
        var config = GridConfig()
        config.indicators = indicators
        try await configureGrid(gridId, config: config)
    }

    public func getConfig(_ gridId: Int64) async throws -> GridConfig {
        var req = GetConfigRequest()
        req.gridId = gridId
        return try await service.getConfig(req)
    }

    public func getSchema(_ gridId: Int64) async throws -> SchemaResponse {
        var req = GetSchemaRequest()
        req.gridId = gridId
        return try await service.getSchema(req)
    }

    // MARK: - Schema (columns, rows)

    public func defineColumns(_ gridId: Int64, columns: [ColumnDef], hostEditorDefaults: Bool = false) async throws {
        var req = DefineColumnsRequest()
        req.gridId = gridId
        req.columns = hostEditorDefaults ? Self.applyHostEditorDefaults(columns) : columns
        _ = try await service.defineColumns(req)
    }

    /// Set the pixel width of a single column.
    public func setColWidth(_ gridId: Int64, col: Int32, width: Int32) async throws {
        var def = ColumnDef()
        def.index = col
        def.width = width
        try await defineColumns(gridId, columns: [def])
    }

    /// Install (or replace) the typed dropdown editor for a column.
    public func setColDropdown(_ gridId: Int64, col: Int32, params: ListEditorParams) async throws {
        var def = ColumnDef()
        def.index = col
        def.editor = Self.listEditorSpec(params)
        try await defineColumns(gridId, columns: [def])
    }

    public func defineRows(_ gridId: Int64, rows: [RowDef]) async throws {
        var req = DefineRowsRequest()
        req.gridId = gridId
        req.rows = rows
        _ = try await service.defineRows(req)
    }

    /// Set the pixel height of a single row.
    public func setRowHeight(_ gridId: Int64, row: Int32, height: Int32) async throws {
        var def = RowDef()
        def.index = row
        def.height = height
        try await defineRows(gridId, rows: [def])
    }

    /// Set the outline (indentation) level for a single row.
    public func setRowOutlineLevel(_ gridId: Int64, row: Int32, level: Int32) async throws {
        var def = RowDef()
        def.index = row
        def.outlineLevel = level
        try await defineRows(gridId, rows: [def])
    }

    private static func listEditorSpec(_ params: ListEditorParams) -> EditorSpec {
        var spec = EditorSpec()
        spec.kind = params.allowCustomValue ? .editorCombo : .editorSelect
        spec.owner = .engine
        spec.presentation = .editorCanvas
        spec.list = params
        return spec
    }

    public static func defaultHostTextEditorSpec() -> EditorSpec {
        var spec = EditorSpec()
        spec.kind = .editorText
        spec.owner = .hostNative
        spec.presentation = .editorInline
        return spec
    }

    public static func defaultHostNumberEditorSpec(nullable: Bool = true) -> EditorSpec {
        var params = NumberEditorParams()
        params.nullable = nullable
        var spec = EditorSpec()
        spec.kind = .editorNumber
        spec.owner = .hostNative
        spec.presentation = .editorInline
        spec.number = params
        return spec
    }

    public static func defaultEngineCheckboxEditorSpec() -> EditorSpec {
        var params = CheckboxEditorParams()
        params.threeState = false
        var spec = EditorSpec()
        spec.kind = .editorCheckbox
        spec.owner = .engine
        spec.presentation = .editorCanvas
        spec.checkbox = params
        return spec
    }

    public static func applyHostEditorDefaults(_ columns: [ColumnDef]) -> [ColumnDef] {
        columns.map { applyHostEditorDefault($0) }
    }

    public static func applyHostEditorDefault(_ column: ColumnDef) -> ColumnDef {
        guard column.editor == nil, let dataType = column.dataType else { return column }
        var next = column
        switch dataType {
        case .columnDataString:
            next.editor = defaultHostTextEditorSpec()
        case .columnDataNumber, .columnDataCurrency:
            next.editor = defaultHostNumberEditorSpec(nullable: column.nullable ?? true)
        case .columnDataBoolean:
            next.editor = defaultEngineCheckboxEditorSpec()
        case .columnDataDate:
            break
        }
        return next
    }

    public func insertRows(_ gridId: Int64, index: Int32, count: Int32, text: [String] = []) async throws {
        var req = InsertRowsRequest()
        req.gridId = gridId
        req.index = index
        req.count = count
        req.text = text
        _ = try await service.insertRows(req)
    }

    public func removeRows(_ gridId: Int64, index: Int32, count: Int32) async throws {
        var req = RemoveRowsRequest()
        req.gridId = gridId
        req.index = index
        req.count = count
        _ = try await service.removeRows(req)
    }

    public func moveColumn(_ gridId: Int64, col: Int32, position: Int32) async throws {
        var req = MoveColumnRequest()
        req.gridId = gridId
        req.col = col
        req.position = position
        _ = try await service.moveColumn(req)
    }

    public func moveRow(_ gridId: Int64, row: Int32, position: Int32) async throws {
        var req = MoveRowRequest()
        req.gridId = gridId
        req.row = row
        req.position = position
        _ = try await service.moveRow(req)
    }

    // MARK: - Data

    public func loadTable(_ gridId: Int64, rows: Int32, cols: Int32, values: [CellValue], atomic: Bool = true) async throws {
        var req = LoadTableRequest()
        req.gridId = gridId
        req.rows = rows
        req.cols = cols
        req.values = values
        req.atomic = atomic
        _ = try await service.loadTable(req)
    }

    public func updateCells(_ gridId: Int64, updates: [CellUpdate], atomic: Bool = true) async throws {
        var req = UpdateCellsRequest()
        req.gridId = gridId
        req.cells = updates
        req.atomic = atomic
        _ = try await service.updateCells(req)
    }

    /// Apply the same `CellStyle` to every cell in the inclusive
    /// `[row1, col1] … [row2, col2]` rectangle.
    public func setCellStyleRange(
        _ gridId: Int64,
        row1: Int32, col1: Int32, row2: Int32, col2: Int32,
        style: CellStyle
    ) async throws {
        var updates: [CellUpdate] = []
        for r in row1...row2 {
            for c in col1...col2 {
                var u = CellUpdate()
                u.row = r
                u.col = c
                u.style = style
                updates.append(u)
            }
        }
        try await updateCells(gridId, updates: updates)
    }

    public func getCells(
        _ gridId: Int64,
        row1: Int32, col1: Int32, row2: Int32, col2: Int32,
        includeStyle: Bool = false,
        includeChecked: Bool = false,
        includeTyped: Bool = false
    ) async throws -> [CellData] {
        var req = GetCellsRequest()
        req.gridId = gridId
        req.row1 = row1
        req.col1 = col1
        req.row2 = row2
        req.col2 = col2
        req.includeStyle = includeStyle
        req.includeChecked = includeChecked
        req.includeTyped = includeTyped
        return try await service.getCells(req).cells
    }

    public func clear(_ gridId: Int64, scope: ClearScope, region: ClearRegion = .clearScrollable) async throws {
        var req = ClearRequest()
        req.gridId = gridId
        req.scope = scope
        req.region = region
        _ = try await service.clear(req)
    }

    // MARK: - Selection / scrolling

    public func select(_ gridId: Int64, row: Int32, col: Int32, ranges: [CellRange] = [], show: Bool? = nil) async throws {
        var req = SelectRequest()
        req.gridId = gridId
        req.activeRow = row
        req.activeCol = col
        req.ranges = ranges
        if let show = show { req.show = show }
        _ = try await service.select(req)
    }

    public func getSelection(_ gridId: Int64) async throws -> SelectionState {
        var req = GetSelectionRequest()
        req.gridId = gridId
        return try await service.getSelection(req)
    }

    public func showCell(_ gridId: Int64, row: Int32, col: Int32) async throws {
        var req = ShowCellRequest()
        req.gridId = gridId
        req.row = row
        req.col = col
        _ = try await service.showCell(req)
    }

    public func setTopRow(_ gridId: Int64, row: Int32) async throws {
        var req = SetRowRequest()
        req.gridId = gridId
        req.row = row
        _ = try await service.setTopRow(req)
    }

    public func setLeftCol(_ gridId: Int64, col: Int32) async throws {
        var req = SetColRequest()
        req.gridId = gridId
        req.col = col
        _ = try await service.setLeftCol(req)
    }

    // MARK: - Analytics

    public func sort(_ gridId: Int64, sorts: [SortColumn]) async throws {
        var req = SortRequest()
        req.gridId = gridId
        req.sortColumns = sorts
        _ = try await service.sort(req)
    }

    public func subtotal(
        _ gridId: Int64,
        aggregate: AggregateType,
        groupOnCol: Int32,
        aggregateCol: Int32,
        caption: String = "",
        background: UInt32 = 0,
        foreground: UInt32 = 0,
        addOutline: Bool = false
    ) async throws -> SubtotalResult {
        var req = SubtotalRequest()
        req.gridId = gridId
        req.aggregate = aggregate
        req.groupOnCol = groupOnCol
        req.aggregateCol = aggregateCol
        req.caption = caption
        req.background = background
        req.foreground = foreground
        req.addOutline = addOutline
        return try await service.subtotal(req)
    }

    /// One grouping level for `addSubtotals`. `groupCol == nil` denotes
    /// the Grand Total row (the engine treats group_on_col = -1 that way).
    public struct SubtotalLevel: Sendable {
        public var groupCol: Int32?
        public var caption: String
        public var background: UInt32
        public var foreground: UInt32

        public init(
            groupCol: Int32? = nil,
            caption: String = "",
            background: UInt32 = 0,
            foreground: UInt32 = 0
        ) {
            self.groupCol = groupCol
            self.caption = caption
            self.background = background
            self.foreground = foreground
        }
    }

    /// Stack one or more subtotal grouping levels over a set of amount
    /// columns. Mirrors `addSubtotals` on the .NET / Java / Flutter
    /// controllers: optionally clears any previous subtotals, enables
    /// `multiTotals` when more than one amount column is supplied, runs
    /// the grouping × amount-column cartesian product, and (if a merge
    /// range is given) merges the label columns on each level-0 row so
    /// the band reads as one continuous Grand Total cell.
    ///
    /// All inner calls run inside `withRedrawSuspended` to suppress
    /// per-call repaints.
    public func addSubtotals(
        _ gridId: Int64,
        amountCols: [Int32],
        levels: [SubtotalLevel],
        aggregate: AggregateType = .aggSum,
        clearExisting: Bool = true,
        mergeColFrom: Int32 = -1,
        mergeColTo: Int32 = -1
    ) async throws {
        guard !amountCols.isEmpty, !levels.isEmpty else { return }

        try await withRedrawSuspended(gridId) {
            if amountCols.count > 1 {
                var outline = OutlineConfig()
                outline.multiTotals = true
                var config = GridConfig()
                config.outline = outline
                try await self.configureGrid(gridId, config: config)
            }

            if clearExisting {
                _ = try await self.subtotal(
                    gridId,
                    aggregate: .aggClear,
                    groupOnCol: 0, aggregateCol: 0,
                    caption: "", background: 0, foreground: 0,
                    addOutline: false
                )
            }

            let wantMerge = mergeColFrom >= 0 && mergeColTo >= mergeColFrom
            for level in levels {
                let groupCol = level.groupCol ?? -1
                for amountCol in amountCols {
                    let result = try await self.subtotal(
                        gridId,
                        aggregate: aggregate,
                        groupOnCol: groupCol,
                        aggregateCol: amountCol,
                        caption: level.caption,
                        background: level.background,
                        foreground: level.foreground,
                        addOutline: true
                    )
                    if wantMerge {
                        try await self.mergeSubtotalLevelZero(
                            gridId, rows: result.rows,
                            colFrom: mergeColFrom, colTo: mergeColTo
                        )
                    }
                }
            }
        }
    }

    private func mergeSubtotalLevelZero(
        _ gridId: Int64,
        rows: [Int32],
        colFrom: Int32,
        colTo: Int32
    ) async throws {
        let uniqueSorted = Set(rows).sorted()
        for row in uniqueSorted {
            let node = try await getNode(gridId, row: row)
            if node.level <= 0 {
                var range = CellRange()
                range.row1 = row
                range.col1 = colFrom
                range.row2 = row
                range.col2 = colTo
                try await mergeCells(gridId, range: range)
            }
        }
    }

    /// Run `action` with engine repainting disabled, then restore.
    /// If `refreshAfter` is true, force one redraw on the way out.
    public func withRedrawSuspended<T>(
        _ gridId: Int64,
        refreshAfter: Bool = true,
        _ action: () async throws -> T
    ) async throws -> T {
        try await setRedraw(gridId, enabled: false)
        do {
            let value = try await action()
            try await setRedraw(gridId, enabled: true)
            if refreshAfter { try await refresh(gridId) }
            return value
        } catch {
            try? await setRedraw(gridId, enabled: true)
            if refreshAfter { try? await refresh(gridId) }
            throw error
        }
    }

    public func autoSize(_ gridId: Int64, colFrom: Int32, colTo: Int32, equal: Bool = false, maxWidth: Int32 = 0) async throws {
        var req = AutoSizeRequest()
        req.gridId = gridId
        req.colFrom = colFrom
        req.colTo = colTo
        req.equal = equal
        req.maxWidth = maxWidth
        _ = try await service.autoSize(req)
    }

    public func outline(_ gridId: Int64, level: Int32) async throws {
        var req = OutlineRequest()
        req.gridId = gridId
        req.level = level
        _ = try await service.outline(req)
    }

    public func getNode(_ gridId: Int64, row: Int32, relation: NodeRelation? = nil) async throws -> NodeInfo {
        var req = GetNodeRequest()
        req.gridId = gridId
        req.row = row
        if let relation = relation { req.relation = relation }
        return try await service.getNode(req)
    }

    /// Search for `text` (or `regex` if non-empty) in `col` starting at
    /// `startRow`. Returns the matching row, or -1 if no match.
    public func find(
        _ gridId: Int64,
        col: Int32,
        startRow: Int32,
        text: String,
        caseSensitive: Bool = false,
        fullMatch: Bool = false,
        regex: String = ""
    ) async throws -> Int32 {
        var req = FindRequest()
        req.gridId = gridId
        req.col = col
        req.startRow = startRow
        if !regex.isEmpty {
            var rq = RegexQuery()
            rq.pattern = regex
            req.query = .regexQuery(rq)
        } else {
            var tq = TextQuery()
            tq.text = text
            tq.caseSensitive = caseSensitive
            tq.fullMatch = fullMatch
            req.query = .textQuery(tq)
        }
        return try await service.find(req).row
    }

    public func aggregate(
        _ gridId: Int64,
        aggregate: AggregateType,
        row1: Int32, col1: Int32, row2: Int32, col2: Int32
    ) async throws -> Double {
        var req = AggregateRequest()
        req.gridId = gridId
        req.aggregate = aggregate
        req.row1 = row1
        req.col1 = col1
        req.row2 = row2
        req.col2 = col2
        return try await service.aggregate(req).value
    }

    // MARK: - Merge

    public func getMergedRange(_ gridId: Int64, row: Int32, col: Int32) async throws -> CellRange {
        var req = GetMergedRangeRequest()
        req.gridId = gridId
        req.row = row
        req.col = col
        return try await service.getMergedRange(req)
    }

    public func mergeCells(_ gridId: Int64, range: CellRange) async throws {
        var req = MergeCellsRequest()
        req.gridId = gridId
        req.range = range
        _ = try await service.mergeCells(req)
    }

    public func unmergeCells(_ gridId: Int64, range: CellRange) async throws {
        var req = UnmergeCellsRequest()
        req.gridId = gridId
        req.range = range
        _ = try await service.unmergeCells(req)
    }

    public func getMergedRegions(_ gridId: Int64) async throws -> [CellRange] {
        var req = GetMergedRegionsRequest()
        req.gridId = gridId
        return try await service.getMergedRegions(req).ranges
    }

    // MARK: - Edit session
    //
    // The engine uses a (sessionId, stateVersion) pair to fence edit
    // commands so a stale UI doesn't apply changes onto a session that
    // has already advanced. The .NET wrapper auto-fetches the current
    // session via `GetEditState` when the caller passes 0; we do the
    // same here. Pass an explicit pair to skip the round-trip.

    public func editStart(
        _ gridId: Int64,
        row: Int32,
        col: Int32,
        reason: EditStartReason,
        seedText: String? = nil,
        caretPosition: Int32? = nil
    ) async throws {
        var start = EditStart()
        start.row = row
        start.col = col
        start.reason = reason
        if let seed = seedText {
            start.seedValue = Self.editorValue(fromText: seed)
        }
        if let cp = caretPosition {
            start.caretPosition = cp
        }
        var cmd = EditCommand()
        cmd.gridId = gridId
        cmd.command = .start(start)
        _ = try await service.edit(cmd)
    }

    public func editCommit(_ gridId: Int64, text: String, sessionId: Int64 = 0, stateVersion: UInt64 = 0) async throws {
        var commit = EditCommit()
        commit.value = Self.editorValue(fromText: text)
        var session = EditorSessionCommand()
        session.command = .commit(commit)
        try await sendEditSessionCommand(gridId, session, sessionId: sessionId, stateVersion: stateVersion)
    }

    public func editCancel(_ gridId: Int64, sessionId: Int64 = 0, stateVersion: UInt64 = 0) async throws {
        var session = EditorSessionCommand()
        session.command = .cancel(EditCancel())
        try await sendEditSessionCommand(gridId, session, sessionId: sessionId, stateVersion: stateVersion)
    }

    public func editSetPreedit(_ gridId: Int64, text: String, cursor: Int32, commit: Bool, sessionId: Int64 = 0, stateVersion: UInt64 = 0) async throws {
        var preedit = EditorPreeditChanged()
        preedit.text = text
        preedit.cursor = cursor
        preedit.commit = commit
        var session = EditorSessionCommand()
        session.command = .preeditChanged(preedit)
        try await sendEditSessionCommand(gridId, session, sessionId: sessionId, stateVersion: stateVersion)
    }

    public func editSetText(_ gridId: Int64, text: String, sessionId: Int64 = 0, stateVersion: UInt64 = 0) async throws {
        var change = EditorValueChanged()
        change.value = Self.editorValue(fromText: text)
        var session = EditorSessionCommand()
        session.command = .valueChanged(change)
        try await sendEditSessionCommand(gridId, session, sessionId: sessionId, stateVersion: stateVersion)
    }

    public func editSetSelection(_ gridId: Int64, start: Int32, length: Int32, sessionId: Int64 = 0, stateVersion: UInt64 = 0) async throws {
        var sel = TextSelection()
        sel.start = start
        sel.length = length
        var changed = TextSelectionChanged()
        changed.selection = sel
        var session = EditorSessionCommand()
        session.command = .selectionChanged(changed)
        try await sendEditSessionCommand(gridId, session, sessionId: sessionId, stateVersion: stateVersion)
    }

    public func getEditState(_ gridId: Int64) async throws -> EditState {
        var cmd = EditCommand()
        cmd.gridId = gridId
        cmd.command = .getState(EditGetState())
        return try await service.edit(cmd)
    }

    private func sendEditSessionCommand(
        _ gridId: Int64,
        _ session: EditorSessionCommand,
        sessionId: Int64,
        stateVersion: UInt64
    ) async throws {
        var session = session
        var sid = sessionId
        var sv = stateVersion
        if (sid == 0 || sv == 0) && gridId != 0 {
            // Best-effort: probe current session so stale callers still apply.
            if let state = try? await getEditState(gridId), state.active, let s = state.session {
                if sid == 0 { sid = s.sessionId }
                if sv == 0 { sv = s.stateVersion }
            }
        }
        if sid != 0 { session.sessionId = sid }
        if sv != 0 { session.stateVersion = sv }
        var cmd = EditCommand()
        cmd.gridId = gridId
        cmd.command = .session(session)
        _ = try await service.edit(cmd)
    }

    private static func editorValue(fromText text: String) -> EditorValue {
        var v = EditorValue()
        var cv = CellValue()
        cv.value = .text(text)
        v.value = cv
        v.editText = text
        v.displayText = text
        return v
    }

    // MARK: - I/O

    /// `action` is one of "copy", "cut", "paste", "delete".
    public func clipboard(_ gridId: Int64, action: String, pasteText: String = "") async throws -> ClipboardResponse {
        var cmd = ClipboardCommand()
        cmd.gridId = gridId
        switch action {
        case "copy":   cmd.command = .copy(ClipboardCopy())
        case "cut":    cmd.command = .cut(ClipboardCut())
        case "paste":
            var p = ClipboardPaste(); p.text = pasteText
            cmd.command = .paste(p)
        case "delete": cmd.command = .delete(ClipboardDelete())
        default: break
        }
        return try await service.clipboard(cmd)
    }

    public func export(_ gridId: Int64, format: ExportFormat, scope: ExportScope) async throws -> ExportResponse {
        var req = ExportRequest()
        req.gridId = gridId
        req.format = format
        req.scope = scope
        return try await service.export(req)
    }

    public func loadData(_ gridId: Int64, data: Data, options: LoadDataOptions? = nil) async throws -> LoadDataResult {
        var req = LoadDataRequest()
        req.gridId = gridId
        req.data = data
        if let options = options { req.options = options }
        return try await service.loadData(req)
    }

    public func appendData(_ gridId: Int64, data: Data, options: LoadDataOptions? = nil) async throws -> LoadDataResult {
        var req = AppendDataRequest()
        req.gridId = gridId
        req.data = data
        if let options = options { req.options = options }
        return try await service.appendData(req)
    }

    public func print(
        _ gridId: Int64,
        landscape: Bool = false,
        marginLeft: Int32 = 0,
        marginTop: Int32 = 0,
        marginRight: Int32 = 0,
        marginBottom: Int32 = 0,
        header: String = "",
        footer: String = "",
        showPageNumbers: Bool = false
    ) async throws {
        var req = PrintRequest()
        req.gridId = gridId
        req.orientation = landscape ? .printLandscape : .printPortrait
        req.marginLeft = marginLeft
        req.marginTop = marginTop
        req.marginRight = marginRight
        req.marginBottom = marginBottom
        req.header = header
        req.footer = footer
        req.showPageNumbers = showPageNumbers
        _ = try await service.print(req)
    }

    public func archive(_ gridId: Int64, action: ArchiveRequest_Action, name: String = "", data: Data? = nil) async throws -> ArchiveResponse {
        var req = ArchiveRequest()
        req.gridId = gridId
        req.action = action
        req.name = name
        if let data = data { req.data = data }
        return try await service.archive(req)
    }

    // MARK: - Demo / viewport / redraw

    public func loadDemo(_ gridId: Int64, demo: String) async throws {
        var req = LoadDemoRequest()
        req.gridId = gridId
        req.demo = demo
        _ = try await service.loadDemo(req)
    }

    public func getDemoData(_ demo: String) async throws -> Data {
        var req = GetDemoDataRequest()
        req.demo = demo
        return try await service.getDemoData(req).data
    }

    public func resizeViewport(_ gridId: Int64, width: Int32, height: Int32) async throws {
        var req = ResizeViewportRequest()
        req.gridId = gridId
        req.width = width
        req.height = height
        _ = try await service.resizeViewport(req)
    }

    public func setRedraw(_ gridId: Int64, enabled: Bool) async throws {
        var req = SetRedrawRequest()
        req.gridId = gridId
        req.enabled = enabled
        _ = try await service.setRedraw(req)
    }

    public func refresh(_ gridId: Int64) async throws {
        var req = RefreshRequest()
        req.gridId = gridId
        _ = try await service.refresh(req)
    }

    // MARK: - Streams

    /// Open a bidirectional render session. Caller sends `RenderInput`
    /// (viewport, pointer, key, buffer) and receives `RenderOutput`
    /// (frame-coupled output: FrameDone, EditorSessionStarted, ...).
    /// The returned stream owns its underlying plugin handle until
    /// closed; the host cascade-closes it on `close()`.
    public func openRenderSession() async throws -> BidiStream<RenderInput, RenderOutput> {
        return try await service.renderSession()
    }

    /// Switch the grid into TUI renderer mode and open a bidi render
    /// session over which the engine will fill an ANSI byte buffer
    /// instead of pixels. Returns a `VolvoxGridTerminalSession` that
    /// owns the stream; tear it down with `await session.close()`.
    ///
    /// Mirrors `VolvoxGridClient.OpenTerminalSession` on the .NET side.
    public func openTerminalSession(_ gridId: Int64) async throws -> VolvoxGridTerminalSession {
        var rendering = RenderConfig()
        rendering.rendererMode = .rendererTui
        var config = GridConfig()
        config.rendering = rendering
        try await configureGrid(gridId, config: config)

        let stream = try await openRenderSession()
        return VolvoxGridTerminalSession(gridId: gridId, stream: stream)
    }

    /// Open the server-streaming event channel for semantic grid events
    /// (selection changed, before/after edit, sort, scroll, etc.).
    /// The request is sent + send-side closed before the stream is
    /// returned, so callers can iterate immediately.
    public func openEventStream(_ gridId: Int64) async throws -> AsyncThrowingStream<GridEvent, Error> {
        var req = EventStreamRequest()
        req.gridId = gridId
        return try await service.eventStream(req)
    }
}
