// SalesExampleApp.swift
//
// Sales demo for VolvoxGrid. This single-file SwiftUI app loads the
// built-in "sales" dataset, defines currency / progress / dropdown
// columns, and stacks three subtotal levels over the Sales and Cost
// amount columns. Level-0 totals merge across the Quarter and Region
// label columns so the band reads as a single "Grand Total" row.
//
// Drop this file into a SwiftUI Xcode project that depends on the
// VolvoxGrid SwiftPM package, replacing the project's generated
// `@main App`. The same source works for iOS and macOS targets.
//
// See ../README.md for how to set up the Xcode project.

import SwiftUI
import VolvoxGrid

@main
struct SalesExampleApp: App {
    var body: some Scene {
        WindowGroup("VolvoxGrid · Sales") {
            DemoView()
        }
    }
}

// Column indices and palette.
private let salesCaptions = [
    "Q", "Region", "Category", "Product",
    "Sales", "Cost", "Margin%", "Flag", "Status", "Notes",
]
private let salesKeys = [
    "Q", "Region", "Category", "Product",
    "Sales", "Cost", "Margin", "Flag", "Status", "Notes",
]
private let salesStatusItems = ["Active", "Pending", "Shipped", "Returned", "Cancelled"]
private let quarterCol: Int32 = 0
private let regionCol: Int32 = 1
private let salesCol: Int32 = 4
private let costCol: Int32 = 5
private let marginCol: Int32 = 6
private let flagCol: Int32 = 7
private let statusCol: Int32 = 8
private let grandTotalBack: UInt32 = 0xFFEEF2FF
private let quarterSubtotalBack: UInt32 = 0xFFF5F3FF
private let regionSubtotalBack: UInt32 = 0xFFF8F7FF
private let marginProgress: UInt32 = 0xFF818CF8

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
            try await loadSales(id)
            self.gridId = id
            self.status = "Sales demo loaded"
        } catch {
            self.status = "Load failed: \(error)"
        }
    }

    private func loadSales(_ id: Int64) async throws {
        try await client.setThemePreset(id, preset: .themeLight)
        try await client.setShowRowIndicator(id, visible: true)

        var outline = OutlineConfig()
        outline.treeIndicator = .treeIndicatorNone
        outline.groupTotalPosition = .groupTotalBelow
        outline.multiTotals = true
        var outlineConfig = GridConfig()
        outlineConfig.outline = outline
        try await client.configureGrid(id, config: outlineConfig)

        try await client.setColCount(id, cols: Int32(salesKeys.count))
        try await client.defineColumns(id, columns: salesColumnDefs(), hostEditorDefaults: true)

        let data = try await client.getDemoData("sales")
        var options = LoadDataOptions()
        options.autoCreateColumns = false
        let result = try await client.loadData(id, data: data, options: options)
        if result.status == .loadFailed {
            throw VolvoxDemoError.loadFailed("sales")
        }

        try await client.setColDropdown(id, col: statusCol, params: salesStatusDropdown())

        try await client.addSubtotals(
            id,
            amountCols: [salesCol, costCol],
            levels: [
                .init(caption: "Grand Total", background: grandTotalBack),
                .init(groupCol: quarterCol, background: quarterSubtotalBack),
                .init(groupCol: regionCol,  background: regionSubtotalBack),
            ],
            mergeColFrom: quarterCol,
            mergeColTo: regionCol
        )

        try await client.autoSize(id, colFrom: salesCol, colTo: costCol)
    }
}

private func salesStatusDropdown() -> ListEditorParams {
    var params = ListEditorParams()
    params.staticItems = salesStatusItems.map { label in
        var item = ListItem()
        item.label = label
        return item
    }
    return params
}

private func salesColumnDefs() -> [ColumnDef] {
    var defs: [ColumnDef] = []
    for col in 0..<Int32(salesKeys.count) {
        var def = ColumnDef()
        def.index = col
        def.caption = salesCaptions[Int(col)]
        def.key = salesKeys[Int(col)]
        switch col {
        case quarterCol:
            def.dataType = .columnDataString
            def.align = .centerCenter
            def.span = true
        case regionCol:
            def.dataType = .columnDataString
            def.span = true
        case 2, 3, statusCol, 9:
            def.dataType = .columnDataString
        case salesCol, costCol:
            def.align = .rightCenter
            def.dataType = .columnDataCurrency
            def.format = "$#,##0"
        case marginCol:
            def.align = .centerCenter
            def.dataType = .columnDataNumber
            def.progressColor = marginProgress
        case flagCol:
            def.align = .centerCenter
            def.dataType = .columnDataBoolean
        default:
            break
        }
        defs.append(def)
    }
    return defs
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
