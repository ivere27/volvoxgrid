// StressExampleApp.swift
//
// Stress demo for VolvoxGrid. This single-file SwiftUI app loads the
// engine's procedurally generated 1,000,000-row by 11-column dataset.
// Exercises render-loop throughput, scrolling, and large-grid memory.
//
// Drop this file into a SwiftUI Xcode project that depends on the
// VolvoxGrid SwiftPM package, replacing the project's generated
// `@main App`. The same source works for iOS and macOS targets.
//
// See ../README.md for how to set up the Xcode project.

import SwiftUI
import VolvoxGrid

@main
struct StressExampleApp: App {
    var body: some Scene {
        WindowGroup("VolvoxGrid · Stress (1M rows)") {
            DemoView()
        }
    }
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
            self.status = "Generating 1,000,000 rows…"
            let id = try await client.createGrid(
                viewportWidth: 0, viewportHeight: 0, scale: 2.0)
            try await client.loadDemo(id, demo: "stress")
            self.gridId = id
            self.status = "Stress demo loaded — scroll, pinch, drag-select"
        } catch {
            self.status = "Load failed: \(error)"
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
