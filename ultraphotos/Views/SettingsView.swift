//
//  SettingsView.swift
//  ultraphotos
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(PreferenceKeys.showMetadata) private var showMetadata: Bool = true
    @Environment(PhotoGridViewModel.self) private var viewModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                Form {
                    Toggle("Show metadata", isOn: $showMetadata)
                    Text("Display date, file size, and video duration on photo thumbnails.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                .formStyle(.grouped)
            }

            Tab("Advanced", systemImage: "gearshape.2") {
                Form {
                    Section {
                        Text("Reconcile the metadata store with your Photos library. This removes stale entries and adds new ones.")
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                Task { await viewModel.reindexLibrary() }
                            } label: {
                                if viewModel.isReindexing {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Reindexing…")
                                } else {
                                    Text("Reindex Library")
                                }
                            }
                            .disabled(viewModel.isReindexing || viewModel.isSyncingMetadata)

                            if let result = viewModel.reindexResult {
                                Text("Removed \(result.removed), added \(result.added) items")
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                            }
                        }
                    } header: {
                        Text("Reindex Library")
                    }
                }
                .formStyle(.grouped)
            }
        }
        .frame(minWidth: 450, minHeight: 200)
    }
}
