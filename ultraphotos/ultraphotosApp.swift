//
//  ultraphotosApp.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import AppKit
import SwiftData
import SwiftUI

struct ExportCommands: Commands {
    @FocusedValue(\.exportMenuTitle) var exportTitle
    @FocusedValue(\.exportEnabled) var exportEnabled

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(exportTitle ?? "Export") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.prompt = "Export"
                panel.begin { _ in
                    // Export logic will be added later
                }
            }
            .disabled(!(exportEnabled ?? false))
        }
    }
}

@main
struct ultraphotosApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema(versionedSchema: MediaMetadataSchemaV1.self)
        let configuration = ModelConfiguration(
            "MediaMetadataStore",
            schema: schema
        )
        do {
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: MediaMetadataMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands { ExportCommands() }
        .modelContainer(modelContainer)
    }
}
