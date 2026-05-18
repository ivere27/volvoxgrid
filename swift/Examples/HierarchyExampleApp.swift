// HierarchyExampleApp.swift
//
// Hierarchy demo for VolvoxGrid. This single-file SwiftUI app loads the
// built-in "hierarchy" dataset, computes each row's outline depth,
// defines typed columns, configures tree indicators, and styles folder
// and action cells.
//
// Drop this file into a SwiftUI Xcode project that depends on the
// VolvoxGrid SwiftPM package, replacing the project's generated
// `@main App`. The same source works for iOS and macOS targets.
//
// See ../README.md for how to set up the Xcode project.

import Foundation
import SwiftUI
import VolvoxGrid

@main
struct HierarchyExampleApp: App {
    var body: some Scene {
        WindowGroup("VolvoxGrid · Hierarchy") {
            DemoView()
        }
    }
}

private let hierCaptions = ["Name", "Type", "Size", "Modified", "Permissions", "Action"]
private let hierKeys = ["Name", "Type", "Size", "Modified", "Permissions", "Action"]
private let hierColWidths: [Int32] = [260, 80, 80, 120, 100, 92]
private let nameCol: Int32 = 0
private let sizeCol: Int32 = 2
private let modifiedCol: Int32 = 3
private let permissionsCol: Int32 = 4
private let actionCol: Int32 = 5
private let treeColor: UInt32 = 0xFFA8A29E
private let folderTextColor: UInt32 = 0xFF92400E
private let actionTextColor: UInt32 = 0xFF2563EB
private let outlineIndent: Int32 = 20
private let minOutlineIndicatorWidth: Int32 = 56
private let nameExpanderWidth: Int32 = 280
private let headerBandRows: Int32 = 1
private let desktopHeaderHeight: Int32 = 28
private let mobileHeaderHeight: Int32 = 44
private let shortDateFormat = "short date"

private var touchHeader: Bool {
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    return true
    #else
    return false
    #endif
}

private var headerHeight: Int32 {
    touchHeader ? mobileHeaderHeight : desktopHeaderHeight
}

@MainActor
final class DemoModel: ObservableObject {
    let client: VolvoxGridClient
    @Published var gridId: Int64 = 0
    @Published var status: String = "Initializing…"

    init() {
        do {
            self.client = try VolvoxGridClient()
        } catch {
            fatalError("VolvoxGrid: failed to attach engine — \(error)")
        }
    }

    func start() async {
        do {
            let id = try await client.createGrid(
                viewportWidth: 0, viewportHeight: 0, scale: 2.0)
            try await loadHierarchy(id)
            self.gridId = id
            self.status = "Hierarchy demo loaded — tap a row indicator to expand"
        } catch {
            self.status = "Load failed: \(error)"
        }
    }

    private func loadHierarchy(_ id: Int64) async throws {
        let rawData = try await client.getDemoData("hierarchy")
        guard let raw = try JSONSerialization.jsonObject(with: rawData) as? [[String: Any]] else {
            throw VolvoxDemoError.loadFailed("hierarchy")
        }
        let levels = try hierarchyLevels(raw)
        let types = raw.map { ($0["Type"] as? String) ?? "" }
        let visible = raw.map { row -> [String: Any] in
            var out: [String: Any] = [:]
            for key in hierKeys { out[key] = row[key] ?? "" }
            return out
        }
        let sanitized = try JSONSerialization.data(withJSONObject: visible)

        try await client.setColCount(id, cols: Int32(hierColWidths.count))
        try await client.defineColumns(id, columns: hierarchyColumnDefs(), hostEditorDefaults: true)

        var options = LoadDataOptions()
        options.autoCreateColumns = false
        let result = try await client.loadData(id, data: sanitized, options: options)
        if result.status == .loadFailed {
            throw VolvoxDemoError.loadFailed("hierarchy")
        }

        let maxDepth = maxVisualDepth(levels)
        let maxLevel = maxOutlineLevel(levels)
        try await client.configureGrid(id, config: hierarchyThemeConfig(
            maxOutlineDepth: maxDepth, maxOutlineLevel: maxLevel))

        var actionStyle = CellStyle()
        actionStyle.foreground = actionTextColor
        var folderStyle = CellStyle()
        folderStyle.foreground = folderTextColor
        var folderFont = Font()
        folderFont.bold = true
        folderStyle.font = folderFont

        for row in 0..<levels.count {
            let r = Int32(row)
            let isFolder = row < types.count && types[row] == "Folder"
            try await client.setRowOutlineLevel(id, row: r, level: Int32(levels[row]))
            try await client.setCellStyleRange(
                id, row1: r, col1: actionCol, row2: r, col2: actionCol, style: actionStyle)
            if isFolder {
                try await client.setCellStyleRange(
                    id, row1: r, col1: nameCol, row2: r, col2: nameCol, style: folderStyle)
            }
        }
    }
}

private func hierarchyColumnDefs() -> [ColumnDef] {
    var defs: [ColumnDef] = []
    for col in 0..<Int32(hierColWidths.count) {
        var def = ColumnDef()
        def.index = col
        def.caption = hierCaptions[Int(col)]
        def.key = hierKeys[Int(col)]
        def.width = hierColWidths[Int(col)]
        switch col {
        case nameCol, 1:
            def.dataType = .columnDataString
        case sizeCol:
            def.align = .rightCenter
        case modifiedCol:
            def.dataType = .columnDataDate
            def.format = shortDateFormat
        case permissionsCol, actionCol:
            def.dataType = .columnDataString
            def.align = .centerCenter
        default:
            break
        }
        if col == actionCol {
            def.interaction = .textLink
        }
        if col == nameCol {
            def.hidden = true
        }
        defs.append(def)
    }
    return defs
}

private func hierarchyLevels(_ rows: [[String: Any]]) throws -> [Int] {
    var rowsById: [String: [String: Any]] = [:]
    for row in rows {
        let id = (row["Id"] as? String) ?? "\(row["Id"] ?? "")"
        if id.isEmpty {
            throw VolvoxDemoError.loadFailed("hierarchy: row missing Id")
        }
        rowsById[id] = row
    }

    var cache: [String: Int] = [:]

    func depthOf(_ row: [String: Any], visiting: inout Set<String>) throws -> Int {
        let id = (row["Id"] as? String) ?? "\(row["Id"] ?? "")"
        if let cached = cache[id] { return cached }
        if !visiting.insert(id).inserted {
            throw VolvoxDemoError.loadFailed("hierarchy: parent cycle at \(id)")
        }
        let parentRaw = row["ParentId"]
        let parentId = (parentRaw as? String) ?? (parentRaw.map { "\($0)" } ?? "")
        var depth = 0
        if !parentId.isEmpty {
            guard let parent = rowsById[parentId] else {
                throw VolvoxDemoError.loadFailed("hierarchy: missing parent \(parentId)")
            }
            depth = try depthOf(parent, visiting: &visiting) + 1
        }
        visiting.remove(id)
        cache[id] = depth
        return depth
    }

    return try rows.map { row in
        var visiting: Set<String> = []
        return try depthOf(row, visiting: &visiting)
    }
}

private func maxVisualDepth(_ levels: [Int]) -> Int32 {
    var hasMin = false
    var minLevel = 0
    var maxLevel = 0
    for level in levels where level >= 0 {
        if !hasMin || level < minLevel {
            hasMin = true
            minLevel = level
        }
        if level > maxLevel { maxLevel = level }
    }
    let depth = maxLevel - minLevel
    return Int32(depth < 0 ? 0 : depth)
}

private func maxOutlineLevel(_ levels: [Int]) -> Int32 {
    var maxLevel = 0
    var hasMax = false
    for level in levels where level >= 0 {
        if !hasMax || level > maxLevel {
            hasMax = true
            maxLevel = level
        }
    }
    return Int32(hasMax ? maxLevel : 0)
}

private func outlineWidth(_ maxOutlineDepth: Int32) -> Int32 {
    let sanitized = maxOutlineDepth < 0 ? 0 : maxOutlineDepth
    let width = (sanitized + 1) * outlineIndent
    return max(width, minOutlineIndicatorWidth)
}

private func expanderWidth(_ maxOutlineDepth: Int32) -> Int32 {
    outlineWidth(maxOutlineDepth) + nameExpanderWidth
}

private func hierarchyThemeConfig(maxOutlineDepth: Int32, maxOutlineLevel: Int32) -> GridConfig {
    let outlineW = outlineWidth(maxOutlineDepth)
    let expanderW = expanderWidth(maxOutlineDepth)

    var layout = LayoutConfig()
    layout.fixedRows = 0

    var selection = SelectionConfig()
    selection.mode = .selectionFree

    var activation = EditActivation()
    activation.trigger = .none
    var editing = EditConfig()
    editing.activation = activation

    var outline = OutlineConfig()
    outline.treeIndicator = .treeIndicatorArrowsLeaf
    outline.indicatorIndent = outlineIndent
    outline.maxLevels = maxOutlineLevel < 0 ? 0 : maxOutlineLevel
    outline.showLevelButtons = true
    outline.labelColumn = nameCol
    outline.treeColor = treeColor

    var resize = ResizePolicy()
    resize.columns = true
    resize.rows = false
    var headerFeatures = HeaderFeatures()
    headerFeatures.sort = false
    headerFeatures.reorder = false
    headerFeatures.chooser = false
    var interaction = InteractionConfig()
    interaction.resize = resize
    interaction.autoSizeMouse = true
    interaction.headerFeatures = headerFeatures

    var rowStart = RowIndicatorConfig()
    rowStart.visible = true
    rowStart.width = expanderW
    rowStart.autoSize = false
    rowStart.allowResize = true
    var expanderSlot = RowIndicatorSlot()
    expanderSlot.kind = .rowIndicatorSlotExpander
    expanderSlot.width = expanderW
    expanderSlot.visible = true
    rowStart.slots = [expanderSlot]

    var cornerTopStart = CornerIndicatorConfig()
    cornerTopStart.visible = true
    var outlineSlot = CornerIndicatorSlot()
    outlineSlot.kind = .cornerSlotOutlineLevels
    outlineSlot.width = outlineW
    outlineSlot.visible = true
    cornerTopStart.slots = [outlineSlot]

    var colTop = ColIndicatorConfig()
    colTop.visible = true
    colTop.defaultRowHeight = headerHeight
    colTop.bandRows = headerBandRows
    var modes = ColIndicatorCellModes()
    modes.modes = [.colIndicatorCellHeaderText]
    colTop.cellModes = modes
    colTop.allowResize = true

    var indicators = IndicatorsConfig()
    indicators.rowStart = rowStart
    indicators.cornerTopStart = cornerTopStart
    indicators.colTop = colTop
    indicators.appearance = .modern

    var config = GridConfig()
    config.themePreset = .themeAmber
    config.layout = layout
    config.selection = selection
    config.editing = editing
    config.outline = outline
    config.interaction = interaction
    config.indicators = indicators
    return config
}

enum VolvoxDemoError: Error, CustomStringConvertible {
    case loadFailed(String)
    var description: String {
        switch self {
        case .loadFailed(let demo): return "LoadData failed for embedded \(demo) demo"
        }
    }
}

struct DemoView: View {
    @StateObject private var model = DemoModel()

    var body: some View {
        VStack(spacing: 0) {
            if model.gridId != 0 {
                VolvoxGridView(client: model.client, gridId: model.gridId)
            } else {
                ProgressView(model.status)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            Text(model.status)
                .font(.caption)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await model.start() }
    }
}
