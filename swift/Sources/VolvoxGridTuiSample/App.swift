// VolvoxGridTuiSample/main.swift
//
// Swift counterpart of dotnet/examples/tui — exercises the VolvoxGrid
// engine in TUI renderer mode from a Linux terminal.
//
// Two modes:
//
//   • Smoke (CI / docker run --rm):
//       VOLVOXGRID_TUI_SMOKE_MODE=1 swift run VolvoxGridTuiSample
//       Loads the demo, opens a terminal session, drives a fixed number
//       of frames, prints a JSON summary, exits 0 on success / 1 on fail.
//
//   • Interactive (docker run --rm -it):
//       swift run VolvoxGridTuiSample --demo sales
//       Goes into termios cbreak mode, sizes itself to the terminal,
//       draws the same host chrome used by the Go / .NET TUI samples,
//       forwards stdin bytes into the engine, writes engine ANSI to
//       stdout, and switches demos with F6 / F7 / F8. Quit with
//       'q' / Ctrl-C / Ctrl-Q.
//
// The native engine is dlopened at runtime — point
// `VOLVOXGRID_LIBRARY_PATH` at the right `libvolvoxgrid.so`. The
// Makefile wires this up so `make swift-tui-run-release` Just Works.

import Dispatch
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import VolvoxGrid

// MARK: - CLI parsing

enum DemoKind: String, CaseIterable {
    case sales
    case hierarchy
    case stress

    var title: String {
        switch self {
        case .sales: return "Sales"
        case .hierarchy: return "Hierarchy"
        case .stress: return "Stress"
        }
    }
}

struct Options {
    var demo: DemoKind = .sales
    var demoProvided: Bool = false
    var smoke: Bool = false
    var smokeFrames: Int = 3
    var width: Int32 = 100
    var height: Int32 = 30
}

func parseOptions(_ args: [String]) -> Options {
    var opts = Options()
    let env = ProcessInfo.processInfo.environment
    if env["VOLVOXGRID_TUI_SMOKE_MODE"] == "1" { opts.smoke = true }
    if let n = env["VOLVOXGRID_TUI_SMOKE_FRAMES"].flatMap(Int.init), n > 0 {
        opts.smokeFrames = n
    }

    var i = 1
    while i < args.count {
        let a = args[i]
        switch a {
        case "--smoke":
            opts.smoke = true
            i += 1
        case "--demo":
            if i + 1 < args.count, let kind = DemoKind(rawValue: args[i + 1].lowercased()) {
                opts.demo = kind
                opts.demoProvided = true
            }
            i += 2
        case "--width":
            if i + 1 < args.count, let w = Int32(args[i + 1]), w > 0 { opts.width = w }
            i += 2
        case "--height":
            if i + 1 < args.count, let h = Int32(args[i + 1]), h > 0 { opts.height = h }
            i += 2
        default:
            i += 1
        }
    }
    return opts
}

// MARK: - Terminal helpers (Linux)

#if canImport(Glibc)

/// Snapshot the terminal size by querying TIOCGWINSZ. Falls back to
/// 80×24 if the call fails (e.g. running under a CI sandbox).
func queryTerminalSize() -> (cols: Int32, rows: Int32) {
    var ws = winsize()
    let rc = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws)
    if rc == 0, ws.ws_col > 0, ws.ws_row > 0 {
        return (Int32(ws.ws_col), Int32(ws.ws_row))
    }
    return (80, 24)
}

/// Put stdin into cbreak (raw, no echo, no canonical) mode. Returns the
/// previous attributes so the caller can restore on exit.
func enterRawMode() -> termios? {
    var old = termios()
    if tcgetattr(STDIN_FILENO, &old) != 0 { return nil }
    var raw = old
    raw.c_lflag &= ~(UInt32(ICANON | ECHO | ISIG))
    raw.c_iflag &= ~(UInt32(IXON | ICRNL))
    raw.c_oflag &= ~(UInt32(OPOST))
    // The interactive host waits on a DispatchSourceRead event, so reads
    // can be blocking: read(2) only runs after stdin is readable.
    raw.c_cc.16 = 1  // VMIN
    raw.c_cc.17 = 0  // VTIME
    if tcsetattr(STDIN_FILENO, TCSANOW, &raw) != 0 { return nil }
    return old
}

func restoreMode(_ saved: termios) {
    var t = saved
    _ = tcsetattr(STDIN_FILENO, TCSANOW, &t)
}

func writeStdout(_ bytes: UnsafeBufferPointer<UInt8>, count: Int) {
    guard count > 0, let base = bytes.baseAddress else { return }
    var written = 0
    while written < count {
        let n = write(STDOUT_FILENO, base.advanced(by: written), count - written)
        if n <= 0 { return }
        written += n
    }
}

func writeStdout(_ text: String) {
    let data = Data(text.utf8)
    data.withUnsafeBytes { raw in
        guard let base = raw.baseAddress else { return }
        var written = 0
        while written < data.count {
            let n = write(STDOUT_FILENO, base.advanced(by: written), data.count - written)
            if n <= 0 { return }
            written += n
        }
    }
}

#else

func queryTerminalSize() -> (cols: Int32, rows: Int32) { (80, 24) }
func enterRawMode() -> termios? { nil }
func restoreMode(_ saved: termios) { }
func writeStdout(_ bytes: UnsafeBufferPointer<UInt8>, count: Int) { }
func writeStdout(_ text: String) { FileHandle.standardOutput.write(Data(text.utf8)) }

#endif

// MARK: - Terminal events

private enum TerminalEvent {
    case input(Data)
    case resize
}

#if canImport(Glibc)
private final class TerminalEventSource {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "VolvoxGridTuiSample.events")
    private let continuation: AsyncStream<TerminalEvent>.Continuation
    private var inputSource: DispatchSourceRead?
    private var resizeSource: DispatchSourceSignal?
    private var closed = false
    let stream: AsyncStream<TerminalEvent>

    init() {
        var captured: AsyncStream<TerminalEvent>.Continuation?
        self.stream = AsyncStream<TerminalEvent>(bufferingPolicy: .unbounded) { continuation in
            captured = continuation
        }
        self.continuation = captured!

        _ = signal(SIGWINCH, SIG_IGN)

        let input = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: queue)
        let resize = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: queue)
        self.inputSource = input
        self.resizeSource = resize

        input.setEventHandler { [weak self] in
            self?.readInput()
        }
        resize.setEventHandler { [weak self] in
            self?.yield(.resize)
        }
        streamContinuationOnTermination { [weak self] in
            self?.close()
        }

        input.resume()
        resize.resume()
        continuation.yield(.resize)
    }

    func close() {
        lock.lock()
        if closed {
            lock.unlock()
            return
        }
        closed = true
        let input = inputSource
        let resize = resizeSource
        inputSource = nil
        resizeSource = nil
        lock.unlock()

        input?.cancel()
        resize?.cancel()
        _ = signal(SIGWINCH, SIG_DFL)
        continuation.finish()
    }

    private func isClosed() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return closed
    }

    private func yield(_ event: TerminalEvent) {
        if !isClosed() {
            continuation.yield(event)
        }
    }

    private func readInput() {
        var buf = [UInt8](repeating: 0, count: 4096)
        let count = buf.withUnsafeMutableBufferPointer { ptr -> Int in
            read(STDIN_FILENO, ptr.baseAddress, ptr.count)
        }
        if count > 0 {
            yield(.input(Data(buf.prefix(count))))
        } else if count == 0 {
            close()
        } else if errno != EINTR && errno != EAGAIN {
            close()
        }
    }

    private func streamContinuationOnTermination(_ body: @escaping () -> Void) {
        continuation.onTermination = { _ in body() }
    }
}
#endif

// MARK: - Demo configuration

func configureDemo(_ client: VolvoxGridClient, _ gridId: Int64, demo: DemoKind) async throws {
    switch demo {
    case .sales:
        try await configureSalesDemo(client, gridId)
    case .hierarchy:
        try await configureHierarchyDemo(client, gridId)
    case .stress:
        try await configureStressDemo(client, gridId)
    }
}

private enum TuiDemoError: Error, CustomStringConvertible {
    case invalidData(String)
    case loadFailed(String)

    var description: String {
        switch self {
        case .invalidData(let demo): return "Invalid embedded demo data: \(demo)"
        case .loadFailed(let demo): return "LoadData failed for embedded \(demo) demo"
        }
    }
}

private let salesStatusItems = ["Active", "Pending", "Shipped", "Returned", "Cancelled"]
private let stressDataRows: Int32 = 1_000_000
private let stressColumnWidths: [Int32] = [16, 9, 10, 7, 12, 5, 10, 24, 11, 8, 16]
private let hierarchyKeys = ["Name", "Type", "Size", "Modified", "Permissions", "Action"]
private let hierarchyNameColumn: Int32 = 0
private let hierarchyNameColumnWidth: Int32 = 28
private let hierarchyOutlineIndent: Int32 = 2
private let hierarchyMinOutlineIndicatorWidth: Int32 = 4

private func configureSalesDemo(_ client: VolvoxGridClient, _ gridId: Int64) async throws {
    let data = try await client.getDemoData("sales")
    let rows = try jsonObjectRows(data, demo: "sales")
    let columns = salesColumns()

    try await client.configureGrid(
        gridId,
        config: salesTuiConfig(rows: Int32(rows.count), cols: Int32(columns.count))
    )
    try await client.defineColumns(gridId, columns: columns)

    var options = LoadDataOptions()
    options.autoCreateColumns = false
    let result = try await client.loadData(gridId, data: data, options: options)
    if result.status == .loadFailed {
        throw TuiDemoError.loadFailed("sales")
    }

    let totalRows = try await applySalesSubtotals(client, gridId, baseRows: result.rows)
    try await client.configureGrid(
        gridId,
        config: layoutOnlyConfig(rows: totalRows, cols: Int32(columns.count))
    )
}

private func configureHierarchyDemo(_ client: VolvoxGridClient, _ gridId: Int64) async throws {
    let rawData = try await client.getDemoData("hierarchy")
    let rows = try jsonObjectRows(rawData, demo: "hierarchy")
    let levels = try hierarchyLevels(rows)
    let loadRows = rows.map { row -> [String: Any] in
        var out: [String: Any] = [:]
        for key in hierarchyKeys { out[key] = row[key] ?? "" }
        return out
    }
    let loadData = try JSONSerialization.data(withJSONObject: loadRows)
    let columns = hierarchyColumns()

    try await client.configureGrid(
        gridId,
        config: hierarchyTuiConfig(
            rows: Int32(rows.count),
            cols: Int32(columns.count),
            maxOutlineDepth: hierarchyMaxOutlineDepth(levels),
            maxOutlineLevel: hierarchyMaxOutlineLevel(levels)
        )
    )
    try await client.defineColumns(gridId, columns: columns)

    var options = LoadDataOptions()
    options.autoCreateColumns = false
    let result = try await client.loadData(gridId, data: loadData, options: options)
    if result.status == .loadFailed {
        throw TuiDemoError.loadFailed("hierarchy")
    }

    var rowDefs: [RowDef] = []
    var updates: [CellUpdate] = []
    var actionStyle = CellStyle()
    actionStyle.foreground = 0xFF2563EB
    var folderStyle = CellStyle()
    folderStyle.foreground = 0xFF92400E
    var folderFont = Font()
    folderFont.bold = true
    folderStyle.font = folderFont

    for index in rows.indices {
        let rowIndex = Int32(index)
        var rowDef = RowDef()
        rowDef.index = rowIndex
        rowDef.outlineLevel = levels[index]
        rowDefs.append(rowDef)

        var actionUpdate = CellUpdate()
        actionUpdate.row = rowIndex
        actionUpdate.col = 5
        actionUpdate.style = actionStyle
        updates.append(actionUpdate)

        let kind = stringValue(rows[index]["Type"])
        if kind.caseInsensitiveCompare("Folder") == .orderedSame {
            var folderUpdate = CellUpdate()
            folderUpdate.row = rowIndex
            folderUpdate.col = hierarchyNameColumn
            folderUpdate.style = folderStyle
            updates.append(folderUpdate)
        }
    }

    try await client.defineRows(gridId, rows: rowDefs)
    if !updates.isEmpty {
        try await client.updateCells(gridId, updates: updates, atomic: false)
    }
}

private func configureStressDemo(_ client: VolvoxGridClient, _ gridId: Int64) async throws {
    try await client.loadDemo(gridId, demo: "stress")
    let columns = stressColumns()
    try await client.defineColumns(gridId, columns: columns)
    try await client.configureGrid(
        gridId,
        config: stressTuiConfig(rows: stressDataRows, cols: Int32(columns.count))
    )
}

private func jsonObjectRows(_ data: Data, demo: String) throws -> [[String: Any]] {
    guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        throw TuiDemoError.invalidData(demo)
    }
    return rows
}

private func layoutOnlyConfig(rows: Int32, cols: Int32) -> GridConfig {
    var config = GridConfig()
    config.layout = tuiLayout(rows: rows, cols: cols)
    return config
}

private func tuiLayout(rows: Int32, cols: Int32) -> LayoutConfig {
    var layout = LayoutConfig()
    layout.rows = rows
    layout.cols = cols
    layout.fixedRows = 0
    layout.fixedCols = 0
    layout.defaultRowHeight = 1
    layout.defaultColWidth = 10
    return layout
}

private func baseTuiConfig(rows: Int32, cols: Int32) -> GridConfig {
    var rendering = RenderConfig()
    rendering.rendererMode = .rendererTui
    var selection = SelectionConfig()
    selection.mode = .selectionFree
    var activation = EditActivation()
    activation.trigger = .keyClick
    var editing = EditConfig()
    editing.activation = activation

    var config = GridConfig()
    config.layout = tuiLayout(rows: rows, cols: cols)
    config.rendering = rendering
    config.selection = selection
    config.editing = editing
    return config
}

private func salesTuiConfig(rows: Int32, cols: Int32) -> GridConfig {
    var config = baseTuiConfig(rows: rows, cols: cols)

    var outline = OutlineConfig()
    outline.treeIndicator = .treeIndicatorNone
    outline.groupTotalPosition = .groupTotalBelow
    outline.multiTotals = true
    config.outline = outline

    var span = SpanConfig()
    span.cellSpan = .cellSpanAdjacent
    span.cellSpanFixed = .cellSpanNone
    span.cellSpanCompare = .spanCompareNoCase
    config.span = span

    config.interaction = sortableHeaderInteraction()
    config.indicators = numberedIndicators(rows: rows, sortable: true)
    return config
}

private func stressTuiConfig(rows: Int32, cols: Int32) -> GridConfig {
    var config = baseTuiConfig(rows: rows, cols: cols)
    config.interaction = sortableHeaderInteraction()
    config.indicators = numberedIndicators(rows: rows, sortable: true)
    return config
}

private func hierarchyTuiConfig(
    rows: Int32,
    cols: Int32,
    maxOutlineDepth: Int32,
    maxOutlineLevel: Int32
) -> GridConfig {
    let outlineWidth = hierarchyOutlineWidth(maxOutlineDepth)
    let expanderWidth = outlineWidth + hierarchyNameColumnWidth
    var config = baseTuiConfig(rows: rows, cols: cols)
    config.themePreset = .themeAmber

    var outline = OutlineConfig()
    outline.treeIndicator = .treeIndicatorConnectorsLeaf
    outline.indicatorIndent = hierarchyOutlineIndent
    outline.maxLevels = maxOutlineLevel
    outline.showLevelButtons = true
    outline.labelColumn = hierarchyNameColumn
    config.outline = outline

    var rowStart = RowIndicatorConfig()
    rowStart.visible = true
    rowStart.width = expanderWidth
    rowStart.autoSize = false
    rowStart.allowResize = false
    var expander = RowIndicatorSlot()
    expander.kind = .rowIndicatorSlotExpander
    expander.width = expanderWidth
    expander.visible = true
    rowStart.slots = [expander]

    var corner = CornerIndicatorConfig()
    corner.visible = true
    var outlineSlot = CornerIndicatorSlot()
    outlineSlot.kind = .cornerSlotOutlineLevels
    outlineSlot.width = outlineWidth
    outlineSlot.visible = true
    corner.slots = [outlineSlot]

    var indicators = IndicatorsConfig()
    indicators.rowStart = rowStart
    indicators.cornerTopStart = corner
    indicators.colTop = columnHeader(sortable: false)
    indicators.appearance = .modern
    config.indicators = indicators
    return config
}

private func sortableHeaderInteraction() -> InteractionConfig {
    var header = HeaderFeatures()
    header.sort = true
    var interaction = InteractionConfig()
    interaction.headerFeatures = header
    return interaction
}

private func numberedIndicators(rows: Int32, sortable: Bool) -> IndicatorsConfig {
    let width = tuiNumberRowIndicatorWidth(rows)
    var slot = RowIndicatorSlot()
    slot.kind = .rowIndicatorSlotNumbers
    slot.width = width
    slot.visible = true

    var rowStart = RowIndicatorConfig()
    rowStart.visible = true
    rowStart.width = width
    rowStart.autoSize = false
    rowStart.allowResize = false
    rowStart.slots = [slot]

    var indicators = IndicatorsConfig()
    indicators.rowStart = rowStart
    indicators.colTop = columnHeader(sortable: sortable)
    return indicators
}

private func columnHeader(sortable: Bool) -> ColIndicatorConfig {
    var modes = ColIndicatorCellModes()
    if sortable {
        modes.modes = [.colIndicatorCellHeaderText, .colIndicatorCellSortGlyph]
    } else {
        modes.modes = [.colIndicatorCellHeaderText]
    }

    var colTop = ColIndicatorConfig()
    colTop.visible = true
    colTop.bandRows = 1
    colTop.defaultRowHeight = 1
    colTop.cellModes = modes
    colTop.allowResize = false
    return colTop
}

private func tuiNumberRowIndicatorWidth(_ rows: Int32) -> Int32 {
    let digits = String(max(Int32(1), rows)).count
    return min(Int32(10), max(Int32(3), Int32(digits + 1)))
}

private func hierarchyOutlineWidth(_ maxOutlineDepth: Int32) -> Int32 {
    let width = (max(Int32(0), maxOutlineDepth) + 1) * hierarchyOutlineIndent
    return max(width, hierarchyMinOutlineIndicatorWidth)
}

private func salesColumns() -> [ColumnDef] {
    return [
        column(0, width: 4, caption: "Q", key: "Q", align: .centerCenter, span: true),
        column(1, width: 10, caption: "Region", key: "Region", span: true),
        column(2, width: 14, caption: "Category", key: "Category"),
        column(3, width: 18, caption: "Product", key: "Product"),
        column(4, width: 12, caption: "Sales", key: "Sales", align: .rightCenter,
               dataType: .columnDataCurrency, format: "$#,##0", editor: numberEditor(min: 0)),
        column(5, width: 12, caption: "Cost", key: "Cost", align: .rightCenter,
               dataType: .columnDataCurrency, format: "$#,##0", editor: numberEditor(min: 0)),
        column(6, width: 10, caption: "Margin%", key: "Margin", align: .centerCenter,
               dataType: .columnDataNumber, editor: numberEditor(min: 0, max: 100), progressColor: 0xFF818CF8),
        column(7, width: 5, caption: "Flag", key: "Flag", align: .centerCenter,
               dataType: .columnDataBoolean),
        column(8, width: 10, caption: "Status", key: "Status", editor: dropdownEditor(salesStatusItems)),
        column(9, width: 18, caption: "Notes", key: "Notes"),
    ]
}

private func hierarchyColumns() -> [ColumnDef] {
    return [
        column(hierarchyNameColumn, width: hierarchyNameColumnWidth, caption: "Name", key: "Name", hidden: true),
        column(1, width: 10, caption: "Type", key: "Type"),
        column(2, width: 9, caption: "Size", key: "Size", align: .rightCenter),
        column(3, width: 12, caption: "Modified", key: "Modified",
               dataType: .columnDataDate, format: "short date"),
        column(4, width: 12, caption: "Permissions", key: "Permissions", align: .centerCenter),
        column(5, width: 8, caption: "Action", key: "Action", align: .centerCenter,
               interaction: .textLink),
    ]
}

private func stressColumns() -> [ColumnDef] {
    return stressColumnWidths.enumerated().map { index, width in
        column(Int32(index), width: width, caption: "", key: "")
    }
}

private func column(
    _ index: Int32,
    width: Int32,
    caption: String,
    key: String,
    align: Align? = nil,
    dataType: ColumnDataType? = nil,
    format: String? = nil,
    editor: EditorSpec? = nil,
    progressColor: UInt32? = nil,
    interaction: CellInteraction? = nil,
    span: Bool? = nil,
    hidden: Bool? = nil
) -> ColumnDef {
    var def = ColumnDef()
    def.index = index
    def.width = width
    if !caption.isEmpty { def.caption = caption }
    if !key.isEmpty { def.key = key }
    def.align = align
    def.dataType = dataType
    def.format = format
    def.editor = editor
    def.progressColor = progressColor
    def.interaction = interaction
    def.span = span
    def.hidden = hidden
    return def
}

private func dropdownEditor(_ labels: [String]) -> EditorSpec {
    var list = ListEditorParams()
    list.staticItems = labels.map { label in
        var item = ListItem()
        item.label = label
        return item
    }
    var spec = EditorSpec()
    spec.kind = .editorSelect
    spec.owner = .engine
    spec.presentation = .editorInline
    spec.list = list
    return spec
}

private func numberEditor(min: Double, max: Double? = nil) -> EditorSpec {
    var params = NumberEditorParams()
    params.min = min
    params.max = max
    params.nullable = false
    var spec = EditorSpec()
    spec.kind = .editorNumber
    spec.owner = .engine
    spec.presentation = .editorCanvas
    spec.number = params
    return spec
}

private func applySalesSubtotals(
    _ client: VolvoxGridClient,
    _ gridId: Int64,
    baseRows: Int32
) async throws -> Int32 {
    var totalRows = baseRows
    let clear = try await client.subtotal(
        gridId,
        aggregate: .aggClear,
        groupOnCol: 0,
        aggregateCol: 0
    )
    totalRows += Int32(clear.rows.count)

    let calls: [(aggregateCol: Int32, groupOnCol: Int32, caption: String, background: UInt32)] = [
        (4, -1, "Grand Total", 0xFFEEF2FF),
        (4, 0, "", 0xFFF5F3FF),
        (4, 1, "", 0xFFF8F7FF),
        (5, -1, "Grand Total", 0xFFEEF2FF),
        (5, 0, "", 0xFFF5F3FF),
        (5, 1, "", 0xFFF8F7FF),
    ]

    for call in calls {
        let result = try await client.subtotal(
            gridId,
            aggregate: .aggSum,
            groupOnCol: call.groupOnCol,
            aggregateCol: call.aggregateCol,
            caption: call.caption,
            background: call.background,
            foreground: 0xFF111827,
            addOutline: true
        )
        try await mergeLevelZeroSubtotalLabels(client, gridId, rows: result.rows)
        totalRows += Int32(result.rows.count)
    }

    return totalRows
}

private func mergeLevelZeroSubtotalLabels(
    _ client: VolvoxGridClient,
    _ gridId: Int64,
    rows: [Int32]
) async throws {
    for row in Set(rows).sorted() {
        let node = try await client.getNode(gridId, row: row)
        if node.level <= 0 {
            var range = CellRange()
            range.row1 = row
            range.col1 = 0
            range.row2 = row
            range.col2 = 1
            try await client.mergeCells(gridId, range: range)
        }
    }
}

private func hierarchyLevels(_ rows: [[String: Any]]) throws -> [Int32] {
    var rowsById: [String: [String: Any]] = [:]
    for row in rows {
        let id = stringValue(row["Id"])
        if id.isEmpty {
            throw TuiDemoError.invalidData("hierarchy: row missing Id")
        }
        rowsById[id] = row
    }

    var cache: [String: Int32] = [:]
    func depth(of id: String, visiting: inout Set<String>) throws -> Int32 {
        if let cached = cache[id] { return cached }
        guard let row = rowsById[id] else {
            throw TuiDemoError.invalidData("hierarchy: missing parent \(id)")
        }
        if !visiting.insert(id).inserted {
            throw TuiDemoError.invalidData("hierarchy: parent cycle at \(id)")
        }

        var level: Int32 = 0
        let parentId = stringValue(row["ParentId"])
        if !parentId.isEmpty {
            level = try depth(of: parentId, visiting: &visiting) + 1
        }
        visiting.remove(id)
        cache[id] = level
        return level
    }

    return try rows.map { row in
        var visiting = Set<String>()
        return try depth(of: stringValue(row["Id"]), visiting: &visiting)
    }
}

private func hierarchyMaxOutlineDepth(_ levels: [Int32]) -> Int32 {
    var minLevel: Int32?
    var maxLevel: Int32 = 0
    for level in levels where level >= 0 {
        minLevel = min(minLevel ?? level, level)
        maxLevel = max(maxLevel, level)
    }
    return max(Int32(0), maxLevel - (minLevel ?? 0))
}

private func hierarchyMaxOutlineLevel(_ levels: [Int32]) -> Int32 {
    return levels.filter { $0 >= 0 }.max() ?? 0
}

private func stringValue(_ value: Any?) -> String {
    switch value {
    case let text as String:
        return text
    case _ as NSNull:
        return ""
    case let number as NSNumber:
        return number.stringValue
    case .some(let wrapped):
        return "\(wrapped)"
    case .none:
        return ""
    }
}

// MARK: - Smoke mode

struct SmokeResult: Encodable {
    let demo: String
    let framesRequested: Int
    let framesObserved: Int
    let totalBytesWritten: Int
    let lastBytesWritten: Int
    let cols: Int32
    let rows: Int32
}

func smokeLog(_ msg: String) {
    FileHandle.standardError.write("[smoke] \(msg)\n".data(using: .utf8) ?? Data())
}

func runSmoke(_ opts: Options) async throws -> Int32 {
    let demos = opts.demoProvided ? [opts.demo] : DemoKind.allCases
    var results: [SmokeResult] = []
    for demo in demos {
        var demoOpts = opts
        demoOpts.demo = demo
        results.append(try await runSingleSmoke(demoOpts))
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let payload = opts.demoProvided
        ? try encoder.encode(results[0])
        : try encoder.encode(results)
    FileHandle.standardOutput.write(payload)
    FileHandle.standardOutput.write(Data([0x0a]))

    return results.allSatisfy { $0.totalBytesWritten > 0 } ? 0 : 1
}

func runSingleSmoke(_ opts: Options) async throws -> SmokeResult {
    smokeLog("init client")
    let client = try VolvoxGridClient()

    do {
        smokeLog("createGrid")
        let gridId = try await client.createGrid(viewportWidth: 0, viewportHeight: 0, scale: 1.0)
        smokeLog("configureDemo \(opts.demo.rawValue)")
        try await configureDemo(client, gridId, demo: opts.demo)

        smokeLog("openTerminalSession")
        let session = try await client.openTerminalSession(gridId)
        await session.setCapabilities(VolvoxGridTerminalCapabilities())
        await session.setViewport(width: opts.width, height: opts.height, fullscreen: true)

        var totalBytes = 0
        var lastBytes = 0
        var observed = 0
        for i in 0..<opts.smokeFrames {
            smokeLog("render \(i)")
            let frame = try await session.render()
            observed += 1
            totalBytes += frame.bytesWritten
            lastBytes = frame.bytesWritten
            smokeLog("frame \(i) kind=\(frame.kind) bytes=\(frame.bytesWritten)")
            if frame.kind == .sessionEnd { break }
        }
        smokeLog("shutdown")
        _ = try await session.shutdown()
        await session.close()
        await client.close()

        return SmokeResult(
            demo: opts.demo.rawValue,
            framesRequested: opts.smokeFrames,
            framesObserved: observed,
            totalBytesWritten: totalBytes,
            lastBytesWritten: lastBytes,
            cols: opts.width,
            rows: opts.height
        )
    } catch {
        await client.close()
        throw error
    }
}

// MARK: - Interactive mode

private struct DemoInstance {
    let kind: DemoKind
    let gridId: Int64
}

private enum HostShortcut {
    case quit
    case switchDemo(DemoKind)
}

private struct FilteredInput {
    var forwarded: Data = Data()
    var shortcut: HostShortcut?
}

private final class ShortcutRouter {
    func filter(_ data: Data) -> FilteredInput {
        if data.isEmpty { return FilteredInput() }

        let bytes = [UInt8](data)
        var forwarded: [UInt8] = []
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case 0x03, 0x11:        // Ctrl-C, Ctrl-Q
                return FilteredInput(forwarded: Data(forwarded), shortcut: .quit)
            case UInt8(ascii: "q"): // plain q, matching the older .NET host
                return FilteredInput(forwarded: Data(forwarded), shortcut: .quit)
            case 0x1B:
                let decoded = decodeFunctionKey(bytes, start: index)
                if decoded.consumed > 0 {
                    if let key = decoded.key, let shortcut = shortcut(forFunctionKey: key) {
                        return FilteredInput(forwarded: Data(forwarded), shortcut: shortcut)
                    }
                    forwarded.append(contentsOf: bytes[index..<(index + decoded.consumed)])
                    index += decoded.consumed
                    continue
                }
                forwarded.append(byte)
                index += 1
            default:
                forwarded.append(byte)
                index += 1
            }
        }

        return FilteredInput(forwarded: Data(forwarded))
    }

    private func shortcut(forFunctionKey key: Int) -> HostShortcut? {
        switch key {
        case 6: return .switchDemo(.sales)
        case 7: return .switchDemo(.hierarchy)
        case 8: return .switchDemo(.stress)
        default: return nil
        }
    }

    private func decodeFunctionKey(_ bytes: [UInt8], start: Int) -> (key: Int?, consumed: Int) {
        let remaining = bytes.count - start
        if remaining <= 1 { return (nil, 1) }

        let second = bytes[start + 1]
        if second == UInt8(ascii: "O") {
            if remaining < 3 { return (nil, remaining) }
            switch bytes[start + 2] {
            case UInt8(ascii: "P"): return (1, 3)
            case UInt8(ascii: "Q"): return (2, 3)
            case UInt8(ascii: "R"): return (3, 3)
            case UInt8(ascii: "S"): return (4, 3)
            default: return (nil, 3)
            }
        }

        if second != UInt8(ascii: "[") {
            return (nil, 2)
        }

        var end = start + 2
        while end < bytes.count {
            if isEscapeTerminator(bytes[end]) {
                let consumed = end - start + 1
                guard bytes[end] == UInt8(ascii: "~") else {
                    return (nil, consumed)
                }
                let payloadBytes = bytes[(start + 2)..<end]
                let payload = String(decoding: payloadBytes, as: UTF8.self)
                let base = payload.split(separator: ";", maxSplits: 1).first.map(String.init) ?? payload
                return (functionKeyNumber(fromCSIParam: base), consumed)
            }
            end += 1
        }

        return (nil, remaining)
    }

    private func isEscapeTerminator(_ byte: UInt8) -> Bool {
        byte >= 0x40 && byte <= 0x7E
    }

    private func functionKeyNumber(fromCSIParam param: String) -> Int? {
        switch param {
        case "11": return 1
        case "12": return 2
        case "13": return 3
        case "14": return 4
        case "15": return 5
        case "17": return 6
        case "18": return 7
        case "19": return 8
        case "20": return 9
        case "21": return 10
        case "23": return 11
        case "24": return 12
        default: return nil
        }
    }
}

private final class DemoController {
    private let client: VolvoxGridClient
    private var instances: [DemoKind: DemoInstance] = [:]
    private var session: VolvoxGridTerminalSession?
    private var activeDemo: DemoKind?

    var currentDemo: DemoKind

    init(client: VolvoxGridClient, demo: DemoKind) {
        self.client = client
        self.currentDemo = demo
    }

    func ensureSession(width: Int32, viewportHeight: Int32) async throws -> VolvoxGridTerminalSession {
        if let session, activeDemo == currentDemo {
            return session
        }

        if let old = session {
            await old.close()
            session = nil
            activeDemo = nil
        }

        let instance = try await ensureInstance(width: width, viewportHeight: viewportHeight)
        let next = try await client.openTerminalSession(instance.gridId)
        session = next
        activeDemo = currentDemo
        return next
    }

    func switchDemo(_ next: DemoKind) -> Bool {
        if currentDemo == next { return false }
        currentDemo = next
        return true
    }

    func currentModeLabel() async -> String {
        guard let activeDemo, let instance = instances[activeDemo] else { return "Ready" }
        if let state = try? await client.getEditState(instance.gridId), state.active {
            return "Edit"
        }
        return "Ready"
    }

    func shutdownActiveSession() async throws -> VolvoxGridTerminalFrame? {
        guard let session else { return nil }
        return try await session.shutdown()
    }

    func close() async {
        if let session {
            await session.close()
            self.session = nil
        }
        for instance in instances.values {
            try? await client.destroyGrid(instance.gridId)
        }
        instances.removeAll()
        activeDemo = nil
    }

    private func ensureInstance(width: Int32, viewportHeight: Int32) async throws -> DemoInstance {
        let demo = currentDemo
        if let existing = instances[demo] {
            return existing
        }

        let gridId = try await client.createGrid(
            viewportWidth: width,
            viewportHeight: viewportHeight,
            scale: 1.0
        )
        do {
            try await configureDemo(client, gridId, demo: demo)
            let instance = DemoInstance(kind: demo, gridId: gridId)
            instances[demo] = instance
            return instance
        } catch {
            try? await client.destroyGrid(gridId)
            throw error
        }
    }
}

private func padLine(_ text: String, width: Int) -> String {
    if width <= 0 { return "" }
    if text.count > width {
        return String(text.prefix(width))
    }
    if text.count < width {
        return text + String(repeating: " ", count: width - text.count)
    }
    return text
}

private func footerText(demo: DemoKind, mode: String) -> String {
    let primary: String
    if demo == .hierarchy {
        primary = "Enter/Space Toggle  F2/i Edit"
    } else {
        primary = "Enter/F2/i Edit"
    }
    return " F6 Sales  F7 Tree  F8 Stress  Ctrl+Q/q Quit  |  current: \(demo.title)" +
        "  |  mode: \(mode)  |  hjkl Move  \(primary)"
}

private func drawChrome(demo: DemoKind, width: Int32, height: Int32, mode: String) {
    let cols = Int(width)
    let rows = Int(height)
    if cols <= 0 || rows <= 0 { return }

    let header = padLine(" VolvoxGrid TUI  |  Demo: \(demo.title)", width: cols)
    let footer = padLine(footerText(demo: demo, mode: mode), width: cols)
    writeStdout("\u{1B}[1;1H\u{1B}[0m\(header)\u{1B}[\(rows);1H\u{1B}[0m\(footer)")
}

private func configureSession(
    _ session: VolvoxGridTerminalSession,
    width: Int32,
    viewportHeight: Int32
) async {
    await session.setCapabilities(VolvoxGridTerminalCapabilities())
    await session.setViewport(
        originX: 0,
        originY: 1,
        width: width,
        height: viewportHeight,
        fullscreen: false
    )
}

func runInteractive(_ opts: Options) async throws -> Int32 {
    let client = try VolvoxGridClient()
    let controller = DemoController(client: client, demo: opts.demo)
    let router = ShortcutRouter()
    let events = TerminalEventSource()

    let savedTermios = enterRawMode()
    defer {
        events.close()
        if let t = savedTermios { restoreMode(t) }
    }

    var terminalWidth: Int32 = 80
    var terminalHeight: Int32 = 24
    var chromeDirty = true
    var needRender = true

    do {
        for await event in events.stream {
            switch event {
            case .resize:
                let size = queryTerminalSize()
                terminalWidth = max(Int32(20), size.cols)
                terminalHeight = max(Int32(6), size.rows)
                chromeDirty = true
                needRender = true

            case .input(let stdinBytes):
                let viewportHeight = max(Int32(1), terminalHeight - 2)
                var session = try await controller.ensureSession(
                    width: terminalWidth,
                    viewportHeight: viewportHeight
                )
                await configureSession(session, width: terminalWidth, viewportHeight: viewportHeight)

                let filtered = router.filter(stdinBytes)
                if !filtered.forwarded.isEmpty {
                    try await session.sendInput(filtered.forwarded)
                    chromeDirty = true
                    needRender = true
                }

                if let shortcut = filtered.shortcut {
                    switch shortcut {
                    case .quit:
                        if let final = try await controller.shutdownActiveSession() {
                            writeStdout(final.bytes, count: final.bytesWritten)
                        }
                        await controller.close()
                        await client.close()
                        return 0
                    case .switchDemo(let next):
                        if controller.switchDemo(next) {
                            chromeDirty = true
                            needRender = true
                        }
                        session = try await controller.ensureSession(
                            width: terminalWidth,
                            viewportHeight: viewportHeight
                        )
                        await configureSession(session, width: terminalWidth, viewportHeight: viewportHeight)
                    }
                }
            }

            if needRender {
                let viewportHeight = max(Int32(1), terminalHeight - 2)
                let session = try await controller.ensureSession(
                    width: terminalWidth,
                    viewportHeight: viewportHeight
                )
                await configureSession(session, width: terminalWidth, viewportHeight: viewportHeight)

                let frame = try await session.render()
                writeStdout(frame.bytes, count: frame.bytesWritten)
                if frame.kind == .sessionEnd { break }

                if chromeDirty {
                    let mode = await controller.currentModeLabel()
                    drawChrome(
                        demo: controller.currentDemo,
                        width: terminalWidth,
                        height: terminalHeight,
                        mode: mode
                    )
                    chromeDirty = false
                }

                needRender = false
            }
        }
    } catch {
        await controller.close()
        await client.close()
        throw error
    }

    await controller.close()
    await client.close()
    return 0
}

// MARK: - Entry point

@main
struct TuiSampleApp {
    static func main() async {
        let opts = parseOptions(CommandLine.arguments)
        do {
            let exitCode: Int32
            if opts.smoke {
                exitCode = try await runSmoke(opts)
            } else {
                exitCode = try await runInteractive(opts)
            }
            exit(exitCode)
        } catch {
            let msg = "VolvoxGridTuiSample failed: \(error)\n"
            FileHandle.standardError.write(msg.data(using: .utf8) ?? Data())
            exit(1)
        }
    }
}
