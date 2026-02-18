//
//  ultraphotosApp.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import SwiftData
import SwiftUI

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
        .modelContainer(modelContainer)
    }
}
