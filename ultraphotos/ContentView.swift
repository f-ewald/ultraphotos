//
//  ContentView.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import SwiftData
import SwiftUI

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
                }
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
                            Text("Loading Metadata \(viewModel.metadataSyncProgress.formatted())/\(viewModel.metadataSyncTotal.formatted())")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                                .monospacedDigit()
                        }
                        Spacer()
                        Text("\(viewModel.filteredAssets.count) items")
                            .foregroundStyle(.secondary)
                            .font(.callout)
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
            }
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
