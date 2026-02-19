//
//  PhotoGridViewModel.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import Photos
import AppKit
import Observation
import SwiftData

enum PhotoAuthorizationState {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
}

enum MediaTypeFilter: String, CaseIterable, Identifiable {
    case all
    case photosOnly
    case videosOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .photosOnly: return "Photos"
        case .videosOnly: return "Videos"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "photo.on.rectangle"
        case .photosOnly: return "photo"
        case .videosOnly: return "video"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case recordTime
    case duration
    case fileSize

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recordTime: return "Record Time"
        case .duration: return "Duration"
        case .fileSize: return "File Size"
        }
    }

    var systemImage: String {
        switch self {
        case .recordTime: return "calendar.circle"
        case .duration: return "timer"
        case .fileSize: return "internaldrive"
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }

    var systemImage: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }
}

struct ExportResult: Equatable {
    let successCount: Int
    let failureCount: Int
    let skippedCount: Int
}

enum FullscreenNavigationDirection {
    case previous
    case next
}

@Observable
final class PhotoGridViewModel {
    static let thumbnailSize = CGSize(width: 300, height: 300)

    private(set) var authorizationState: PhotoAuthorizationState = .notDetermined
    private(set) var assets: [PhotoAsset] = []
    private let thumbnailCache = NSCache<NSString, NSImage>()
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var mediaFilter: MediaTypeFilter = .all {
        didSet { updateFilteredAssets() }
    }
    var sortOption: SortOption = .recordTime {
        didSet { updateFilteredAssets() }
    }
    var sortOrder: SortOrder = .descending {
        didSet { updateFilteredAssets() }
    }
    private(set) var isSyncingMetadata = false
    private(set) var metadataSyncProgress: Int = 0
    private(set) var metadataSyncTotal: Int = 0
    private(set) var metadataCache: [String: MediaMetadata] = [:]
    private(set) var selectedIdentifiers: Set<String> = []
    private(set) var lastClickedIdentifier: String?
    private(set) var isExporting = false
    private(set) var exportProgress: Int = 0
    private(set) var exportTotal: Int = 0
    private(set) var exportResult: ExportResult?
    private(set) var fullscreenAssetIdentifier: String?
    private(set) var fullscreenImage: NSImage?
    private(set) var isLoadingFullscreenImage = false

    var isFullscreenActive: Bool {
        fullscreenAssetIdentifier != nil
    }

    private var modelContainer: ModelContainer?
    private let service: PhotoLibraryServing
    private var filterGeneration: UInt64 = 0

    #if !SCREENSHOTS
    private var phAssetsByIdentifier: [String: PHAsset] = [:]
    #endif

    init(service: PhotoLibraryServing = PhotoLibraryService()) {
        self.service = service
        thumbnailCache.countLimit = 300
        authorizationState = Self.mapStatus(service.authorizationStatus(for: .readWrite))
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func checkAuthorizationStatus() {
        let status = service.authorizationStatus(for: .readWrite)
        authorizationState = Self.mapStatus(status)
    }

    func requestAuthorization() async {
        let status = await service.requestAuthorization(for: .readWrite)
        authorizationState = Self.mapStatus(status)

        if authorizationState == .authorized || authorizationState == .limited {
            await fetchAssets()
        }
    }

    func fetchAssets() async {
        isLoading = true
        errorMessage = nil

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        let result = service.fetchAssets(with: options)
        var fetchedPHAssets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetchedPHAssets.append(asset)
        }

        #if !SCREENSHOTS
        var lookup: [String: PHAsset] = [:]
        lookup.reserveCapacity(fetchedPHAssets.count)
        for phAsset in fetchedPHAssets {
            lookup[phAsset.localIdentifier] = phAsset
        }
        phAssetsByIdentifier = lookup
        #endif

        assets = fetchedPHAssets.map { PhotoAsset(from: $0) }
        updateFilteredAssets()
        isLoading = false

        await loadMetadataCache()
        await syncMetadata()
    }

    func loadThumbnail(for identifier: String) async -> NSImage? {
        let key = identifier as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }

        #if SCREENSHOTS
        // Regenerate gradient on cache miss (handles NSCache eviction)
        if let index = assets.firstIndex(where: { $0.id == identifier }) {
            let image = DemoDataProvider.generateGradientImage(
                size: Self.thumbnailSize,
                identifier: identifier,
                index: index
            )
            thumbnailCache.setObject(image, forKey: key)
            return image
        }
        return nil
        #else
        guard let phAsset = phAssetsByIdentifier[identifier] else { return nil }

        let image = await service.requestImage(
            for: phAsset,
            targetSize: Self.thumbnailSize,
            contentMode: .aspectFill,
            options: nil
        )
        if let image {
            thumbnailCache.setObject(image, forKey: key)
        }
        return image
        #endif
    }

    func loadMetadataCache() async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MediaMetadata>()
        do {
            let records = try context.fetch(descriptor)
            var cache: [String: MediaMetadata] = [:]
            for record in records {
                cache[record.localIdentifier] = record
            }
            metadataCache = cache
            updateFilteredAssets()
        } catch {
            errorMessage = "Failed to load metadata cache: \(error.localizedDescription)"
        }
    }

    func syncMetadata() async {
        #if SCREENSHOTS
        // No metadata sync needed in demo mode
        return
        #else
        guard let container = modelContainer, !isSyncingMetadata else { return }

        isSyncingMetadata = true
        metadataSyncProgress = 0
        metadataSyncTotal = 0

        let assetsSnapshot = assets
        let phAssets = phAssetsByIdentifier
        let viewModel = self
        let result: [String: MediaMetadata]? = await Task.detached {
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<MediaMetadata>()
            let existingRecords: [MediaMetadata]
            do {
                existingRecords = try context.fetch(descriptor)
            } catch {
                return nil as [String: MediaMetadata]?
            }

            // Deletion pass: remove records for assets no longer in the library
            let currentAssetIDs = Set(assetsSnapshot.map(\.id))
            let staleRecords = existingRecords.filter { !currentAssetIDs.contains($0.localIdentifier) }
            for record in staleRecords {
                context.delete(record)
            }
            if !staleRecords.isEmpty {
                try? context.save()
            }

            let remainingIDs = Set(existingRecords.map(\.localIdentifier)).subtracting(staleRecords.map(\.localIdentifier))
            let toSync = assetsSnapshot.filter { !remainingIDs.contains($0.id) }
            let total = toSync.count
            await MainActor.run { viewModel.metadataSyncTotal = total }

            var insertCount = 0
            for photoAsset in toSync {
                guard let asset = phAssets[photoAsset.id] else { continue }
                let resources = PHAssetResource.assetResources(for: asset)
                let fileSize: Int64
                if let resource = resources.first,
                   let size = resource.value(forKey: "fileSize") as? Int64 {
                    fileSize = size
                } else {
                    fileSize = 0
                }

                let metadata = MediaMetadata(
                    localIdentifier: asset.localIdentifier,
                    fileSize: fileSize,
                    creationDate: asset.creationDate,
                    duration: asset.duration,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
                context.insert(metadata)
                insertCount += 1

                if insertCount % 100 == 0 {
                    try? context.save()
                    let count = insertCount
                    await MainActor.run { viewModel.metadataSyncProgress = count }
                }
            }

            try? context.save()
            await MainActor.run { viewModel.metadataSyncProgress = total }

            // Fetch all records to return as the updated cache
            let allDescriptor = FetchDescriptor<MediaMetadata>()
            do {
                let allRecords = try context.fetch(allDescriptor)
                var cache: [String: MediaMetadata] = [:]
                for record in allRecords {
                    cache[record.localIdentifier] = record
                }
                return cache
            } catch {
                return nil as [String: MediaMetadata]?
            }
        }.value

        if let result {
            metadataCache = result
            updateFilteredAssets()
        }
        isSyncingMetadata = false
        #endif
    }

    func refreshMetadata() async {
        guard !isSyncingMetadata else { return }
        await fetchAssets()
        thumbnailCache.removeAllObjects()
    }

    static func rangeSelection(
        in orderedIdentifiers: [String],
        from anchor: String,
        to target: String
    ) -> Set<String>? {
        guard let anchorIndex = orderedIdentifiers.firstIndex(of: anchor),
              let targetIndex = orderedIdentifiers.firstIndex(of: target) else {
            return nil
        }
        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        return Set(orderedIdentifiers[range])
    }

    func handleThumbnailClick(identifier: String, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            // Cmd+Click: toggle individual item
            if selectedIdentifiers.contains(identifier) {
                selectedIdentifiers.remove(identifier)
            } else {
                selectedIdentifiers.insert(identifier)
            }
            lastClickedIdentifier = identifier
        } else if modifiers.contains(.shift), let lastClicked = lastClickedIdentifier {
            // Shift+Click: select contiguous range from anchor to target
            let identifiers = filteredAssets.map(\.id)
            if let rangeSet = Self.rangeSelection(in: identifiers, from: lastClicked, to: identifier) {
                selectedIdentifiers = rangeSet
            } else {
                // Anchor or target not in current filtered list — fall back to plain click
                selectedIdentifiers = [identifier]
                lastClickedIdentifier = identifier
            }
            // Note: lastClickedIdentifier is NOT updated on shift-click (Finder behavior —
            // the anchor stays fixed so repeated shift-clicks adjust the range end)
        } else {
            // Plain click: select only this item
            selectedIdentifiers = [identifier]
            lastClickedIdentifier = identifier
        }
    }

    func clearExportResult() {
        exportResult = nil
    }

    func exportAssets(to directoryURL: URL) async {
        #if SCREENSHOTS
        exportResult = ExportResult(successCount: 0, failureCount: 0, skippedCount: 0)
        return
        #else
        guard !isExporting else { return }

        let selectedPhAssets = selectedAssets.compactMap { phAssetsByIdentifier[$0.id] }
        guard !selectedPhAssets.isEmpty else {
            exportResult = ExportResult(successCount: 0, failureCount: 0, skippedCount: 0)
            return
        }

        isExporting = true
        exportProgress = 0
        exportTotal = selectedPhAssets.count
        exportResult = nil

        let service = self.service
        let viewModel = self

        let result: ExportResult = await Task.detached {
            var successCount = 0
            var failureCount = 0
            var skippedCount = 0

            for asset in selectedPhAssets {
                let resources = PHAssetResource.assetResources(for: asset)
                guard let resource = resources.first else {
                    failureCount += 1
                    let progress = successCount + failureCount + skippedCount
                    await MainActor.run { viewModel.exportProgress = progress }
                    continue
                }

                let destinationURL = directoryURL.appendingPathComponent(resource.originalFilename)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    skippedCount += 1
                    let progress = successCount + failureCount + skippedCount
                    await MainActor.run { viewModel.exportProgress = progress }
                    continue
                }

                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true

                do {
                    try await service.writeAssetResource(resource, toFileURL: destinationURL, options: options)
                    successCount += 1
                } catch {
                    failureCount += 1
                }

                let progress = successCount + failureCount + skippedCount
                await MainActor.run { viewModel.exportProgress = progress }
            }

            return ExportResult(successCount: successCount, failureCount: failureCount, skippedCount: skippedCount)
        }.value

        isExporting = false
        exportResult = result
        #endif
    }

    func openInPhotos(identifier: String) {
        let uuid = identifier.components(separatedBy: "/").first ?? identifier
        if let url = URL(string: "photos-navigation://show-asset?localIdentifier=\(uuid)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openFullscreen(identifier: String) {
        fullscreenAssetIdentifier = identifier
        fullscreenImage = nil
        isLoadingFullscreenImage = true
    }

    func closeFullscreen() {
        fullscreenAssetIdentifier = nil
        fullscreenImage = nil
        isLoadingFullscreenImage = false
    }

    func loadFullscreenImage() async {
        guard let identifier = fullscreenAssetIdentifier,
              let asset = filteredAssets.first(where: { $0.id == identifier }) else {
            isLoadingFullscreenImage = false
            return
        }

        let maxDimension: CGFloat = 4096
        let width = min(CGFloat(asset.pixelWidth), maxDimension)
        let height = min(CGFloat(asset.pixelHeight), maxDimension)
        let targetSize = CGSize(width: width, height: height)

        #if SCREENSHOTS
        let index = filteredAssets.firstIndex(where: { $0.id == identifier }) ?? 0
        let image = DemoDataProvider.generateGradientImage(
            size: targetSize,
            identifier: identifier,
            index: index
        )
        guard fullscreenAssetIdentifier == identifier else { return }
        fullscreenImage = image
        isLoadingFullscreenImage = false
        #else
        guard let phAsset = phAssetsByIdentifier[identifier] else {
            isLoadingFullscreenImage = false
            return
        }

        let image = await service.requestImage(
            for: phAsset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: nil
        )

        // Check the identifier hasn't changed during the async load
        guard fullscreenAssetIdentifier == identifier else { return }
        fullscreenImage = image
        isLoadingFullscreenImage = false
        #endif
    }

    func navigateFullscreen(direction: FullscreenNavigationDirection) {
        guard let current = fullscreenAssetIdentifier else { return }
        let identifiers = filteredAssets.map(\.id)
        if let next = Self.navigatedIdentifier(in: identifiers, from: current, direction: direction) {
            openFullscreen(identifier: next)
        }
    }

    static func navigatedIdentifier(
        in identifiers: [String],
        from current: String,
        direction: FullscreenNavigationDirection
    ) -> String? {
        guard !identifiers.isEmpty,
              let index = identifiers.firstIndex(of: current) else {
            return nil
        }
        switch direction {
        case .next:
            let nextIndex = (index + 1) % identifiers.count
            return identifiers[nextIndex]
        case .previous:
            let prevIndex = (index - 1 + identifiers.count) % identifiers.count
            return identifiers[prevIndex]
        }
    }

    func clearSelection() {
        selectedIdentifiers.removeAll()
        lastClickedIdentifier = nil
    }

    func selectAll() {
        selectedIdentifiers = Set(filteredAssets.map(\.id))
    }

    var selectedCount: Int {
        guard !selectedIdentifiers.isEmpty else { return 0 }
        let visibleIDs = Set(filteredAssets.map(\.id))
        return selectedIdentifiers.intersection(visibleIDs).count
    }

    var selectedAssets: [PhotoAsset] {
        guard !selectedIdentifiers.isEmpty else { return [] }
        return filteredAssets.filter { selectedIdentifiers.contains($0.id) }
    }

    var photoCount: Int {
        filteredAssets.filter { !$0.isVideo }.count
    }

    var videoCount: Int {
        filteredAssets.filter { $0.isVideo }.count
    }

    var totalFileSize: Int64 {
        let visibleIDs = Set(filteredAssets.map(\.id))
        return metadataCache.values
            .filter { visibleIDs.contains($0.localIdentifier) }
            .reduce(0) { $0 + $1.fileSize }
    }

    var exportTitle: String {
        let photoCount = selectedAssets.filter { !$0.isVideo }.count
        let videoCount = selectedAssets.filter { $0.isVideo }.count
        return Self.exportMenuTitle(photoCount: photoCount, videoCount: videoCount)
    }

    static func exportMenuTitle(photoCount: Int, videoCount: Int) -> String {
        switch (photoCount, videoCount) {
        case (0, 0):
            return "Export"
        case (let p, 0):
            return "Export \(p) \(p == 1 ? "Photo" : "Photos")"
        case (0, let v):
            return "Export \(v) \(v == 1 ? "Video" : "Videos")"
        case (let p, let v):
            return "Export \(p) \(p == 1 ? "Photo" : "Photos") and \(v) \(v == 1 ? "Video" : "Videos")"
        }
    }

    private(set) var filteredAssets: [PhotoAsset] = []

    private func updateFilteredAssets() {
        let filtered: [PhotoAsset]
        switch mediaFilter {
        case .all:
            filtered = assets
        case .photosOnly:
            filtered = assets.filter { !$0.isVideo }
        case .videosOnly:
            filtered = assets.filter { $0.isVideo }
        }

        // The fetch already returns assets sorted by creationDate descending,
        // so skip re-sorting when that matches the current sort settings.
        if sortOption == .recordTime && sortOrder == .descending {
            filteredAssets = filtered
            return
        }

        // Show filtered (unsorted) results immediately so the UI stays populated
        // while the background sort runs.
        filteredAssets = filtered

        filterGeneration &+= 1
        let generation = filterGeneration
        let option = sortOption
        let order = sortOrder

        // Pre-extract file sizes into a plain dictionary so the background
        // closure only captures Sendable values (no @Model objects).
        let fileSizes: [String: Int64]?
        if option == .fileSize {
            var sizes: [String: Int64] = [:]
            sizes.reserveCapacity(metadataCache.count)
            for (id, meta) in metadataCache {
                sizes[id] = meta.fileSize
            }
            fileSizes = sizes
        } else {
            fileSizes = nil
        }

        Task.detached {
            let sorted = filtered.sorted { a, b in
                let result: Bool
                switch option {
                case .recordTime:
                    let dateA = a.creationDate ?? .distantPast
                    let dateB = b.creationDate ?? .distantPast
                    result = dateA < dateB
                case .duration:
                    result = a.duration < b.duration
                case .fileSize:
                    let sizeA = fileSizes?[a.id] ?? 0
                    let sizeB = fileSizes?[b.id] ?? 0
                    result = sizeA < sizeB
                }
                return order == .ascending ? result : !result
            }
            await MainActor.run { [weak self] in
                guard let self, self.filterGeneration == generation else { return }
                self.filteredAssets = sorted
            }
        }
    }

    private static func mapStatus(_ status: PHAuthorizationStatus) -> PhotoAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }

    // MARK: - Demo mode

    #if SCREENSHOTS
    static func demoViewModel() -> PhotoGridViewModel {
        let viewModel = PhotoGridViewModel(service: DemoPhotoLibraryService())
        viewModel.authorizationState = .authorized

        let demoAssets = DemoDataProvider.generateAssets()
        viewModel.assets = demoAssets
        viewModel.filteredAssets = demoAssets

        DemoDataProvider.populateThumbnailCache(
            viewModel.thumbnailCache,
            for: demoAssets,
            size: thumbnailSize
        )

        // Create in-memory ModelContainer with demo metadata
        let schema = Schema(versionedSchema: MediaMetadataSchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            viewModel.modelContainer = container
            let context = ModelContext(container)
            var cache: [String: MediaMetadata] = [:]
            for (index, asset) in demoAssets.enumerated() {
                // Realistic file sizes: photos 2-12 MB, videos 20-120 MB
                let fileSize: Int64 = asset.isVideo
                    ? Int64((index + 1) * 10_000_000 + 20_000_000)
                    : Int64((index + 1) * 500_000 + 2_000_000)
                let metadata = MediaMetadata(
                    localIdentifier: asset.id,
                    fileSize: fileSize,
                    creationDate: asset.creationDate,
                    duration: asset.duration,
                    latitude: nil,
                    longitude: nil
                )
                context.insert(metadata)
                cache[asset.id] = metadata
            }
            try? context.save()
            viewModel.metadataCache = cache
        }

        return viewModel
    }
    #endif

    // MARK: - Testing

    #if DEBUG
    func setAssetsForTesting(_ testAssets: [PhotoAsset]) {
        assets = testAssets
        updateFilteredAssets()
    }
    #endif
}
