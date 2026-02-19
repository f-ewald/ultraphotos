//
//  ContentView.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import SwiftData
import SwiftUI

struct FocusedExportTitleKey: FocusedValueKey {
    typealias Value = String
}

struct FocusedExportEnabledKey: FocusedValueKey {
    typealias Value = Bool
}

struct FocusedExportActionKey: FocusedValueKey {
    typealias Value = (URL) -> Void
}

extension FocusedValues {
    var exportMenuTitle: String? {
        get { self[FocusedExportTitleKey.self] }
        set { self[FocusedExportTitleKey.self] = newValue }
    }
    var exportEnabled: Bool? {
        get { self[FocusedExportEnabledKey.self] }
        set { self[FocusedExportEnabledKey.self] = newValue }
    }
    var exportAction: ((URL) -> Void)? {
        get { self[FocusedExportActionKey.self] }
        set { self[FocusedExportActionKey.self] = newValue }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PhotoGridViewModel()
    @State private var thumbnailSize: CGFloat = 150

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize, maximum: thumbnailSize + 50))]
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.authorizationState {
                case .notDetermined:
                    promptView
                case .authorized, .limited:
                    gridView
                case .denied:
                    deniedView
                case .restricted:
                    restrictedView
                }
            }
            .navigationTitle("UltraPhotos")
            .toolbar {
                if viewModel.authorizationState == .authorized || viewModel.authorizationState == .limited {
                    ToolbarItem {
                        Picker("Media Type", selection: Bindable(viewModel).mediaFilter) {
                            ForEach(MediaTypeFilter.allCases) { filter in
                                Label(filter.label, systemImage: filter.systemImage)
                                    .tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    ToolbarItem {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .imageScale(.small)
                            Slider(value: $thumbnailSize, in: 60...300)
                                .frame(width: 120)
                            Image(systemName: "photo")
                                .imageScale(.large)
                        }
                    }
                    ToolbarItem {
                        Picker("Sort By", selection: Bindable(viewModel).sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    ToolbarItem {
                        Button {
                            viewModel.sortOrder = viewModel.sortOrder == .ascending
                                ? .descending : .ascending
                        } label: {
                            Image(systemName: viewModel.sortOrder.systemImage)
                        }
                        .help(viewModel.sortOrder == .ascending ? "Sort Ascending" : "Sort Descending")
                    }
                    ToolbarItem {
                        Button {
                            Task { await viewModel.refreshMetadata() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh Metadata")
                        .disabled(viewModel.isSyncingMetadata)
                    }
                }
            }
        }
        .focusedSceneValue(\.exportMenuTitle, viewModel.exportTitle)
        .focusedSceneValue(\.exportEnabled, !viewModel.selectedAssets.isEmpty && !viewModel.isExporting)
        .focusedSceneValue(\.exportAction) { [viewModel] url in
            Task { await viewModel.exportAssets(to: url) }
        }
        .overlay {
            if viewModel.isFullscreenActive {
                FullscreenImageView(viewModel: viewModel)
            }
        }
        .overlay(alignment: .topLeading) {
            if viewModel.isExporting {
                HStack(spacing: 8) {
                    ProgressView(value: Double(viewModel.exportProgress), total: Double(max(viewModel.exportTotal, 1)))
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                    Text("Exporting \(viewModel.exportProgress)/\(viewModel.exportTotal)")
                        .font(.callout)
                        .monospacedDigit()
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(12)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.exportResult != nil },
            set: { if !$0 { viewModel.clearExportResult() } }
        )) {
            if let result = viewModel.exportResult {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("Export Complete")
                        .font(.headline)
                    Text(exportResultMessage(result))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("OK") { viewModel.clearExportResult() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(24)
                .frame(minWidth: 260)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.authorizationState == .authorized || viewModel.authorizationState == .limited {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        if viewModel.isSyncingMetadata {
                            ProgressView()
                                .controlSize(.small)
                            Text("Syncing Metadata \(viewModel.metadataSyncProgress.formatted())/\(viewModel.metadataSyncTotal.formatted())")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                                .monospacedDigit()
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            if viewModel.selectedCount > 0 {
                                Text("\(viewModel.selectedCount) of \(viewModel.filteredAssets.count) selected")
                                    .foregroundStyle(.secondary)
                                    .font(.callout)
                            }

                            Label("\(viewModel.photoCount)", systemImage: "photo")
                                .foregroundStyle(.secondary)
                                .font(.callout)

                            Label("\(viewModel.videoCount)", systemImage: "video")
                                .foregroundStyle(.secondary)
                                .font(.callout)

                            Text(ByteCountFormatter.string(fromByteCount: viewModel.totalFileSize, countStyle: .file))
                                .foregroundStyle(.secondary)
                                .font(.callout)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .background(.bar)
            }
        }
        .task {
            viewModel.configure(modelContainer: modelContext.container)
            viewModel.checkAuthorizationStatus()
            if viewModel.authorizationState == .notDetermined {
                await viewModel.requestAuthorization()
            } else if viewModel.authorizationState == .authorized || viewModel.authorizationState == .limited {
                await viewModel.fetchAssets()
            }
        }
    }

    private var promptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("UltraPhotos needs access to your Photos library.")
                .font(.headline)
            Text("Grant access to view and analyze your photo metadata.")
                .foregroundStyle(.secondary)
            Button("Grant Access") {
                Task {
                    await viewModel.requestAuthorization()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridView: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if viewModel.filteredAssets.isEmpty {
                Text("No photos or videos found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(viewModel.filteredAssets, id: \.localIdentifier) { asset in
                        PhotoThumbnailView(asset: asset, viewModel: viewModel, size: thumbnailSize)
                    }
                }
                .padding(4)

                VStack(spacing: 4) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text(appVersionString)
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .background {
            Button("Select All") { viewModel.selectAll() }
                .keyboardShortcut("a", modifiers: .command)
                .hidden()
        }
        .onKeyPress(.escape) {
            if viewModel.isFullscreenActive {
                viewModel.closeFullscreen()
            } else {
                viewModel.clearSelection()
            }
            return .handled
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Photos Access Denied")
                .font(.headline)
            Text("Open System Settings to grant UltraPhotos access to your Photos library.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "v\(version) (\(build))"
    }

    private func exportResultMessage(_ result: ExportResult) -> String {
        var lines: [String] = []
        if result.successCount > 0 {
            lines.append("\(result.successCount) exported successfully")
        }
        if result.skippedCount > 0 {
            lines.append("\(result.skippedCount) skipped (already exist)")
        }
        if result.failureCount > 0 {
            lines.append("\(result.failureCount) failed")
        }
        if lines.isEmpty {
            lines.append("No items to export")
        }
        return lines.joined(separator: "\n")
    }

    private var restrictedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Photos Access Restricted")
                .font(.headline)
            Text("Photo library access is restricted on this device. This may be due to parental controls or device management.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
