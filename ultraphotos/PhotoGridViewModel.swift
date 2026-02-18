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

@Observable
final class PhotoGridViewModel {
    static let thumbnailSize = CGSize(width: 300, height: 300)

    private(set) var authorizationState: PhotoAuthorizationState = .notDetermined
    private(set) var assets: [PHAsset] = []
    private(set) var thumbnails: [String: NSImage] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var mediaFilter: MediaTypeFilter = .all
    var sortOption: SortOption = .recordTime
    var sortOrder: SortOrder = .descending
    private(set) var isSyncingMetadata = false
    private(set) var metadataSyncProgress: Int = 0
    private(set) var metadataSyncTotal: Int = 0
    private(set) var metadataCache: [String: MediaMetadata] = [:]

    private var modelContainer: ModelContainer?
    private let service: PhotoLibraryServing

    init(service: PhotoLibraryServing = PhotoLibraryService()) {
        self.service = service
    }

    func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func checkAuthorizationStatus() {
        let status = service.authorizationStatus(for: .readWrite)
        authorizationState = mapStatus(status)
    }

    func requestAuthorization() async {
        let status = await service.requestAuthorization(for: .readWrite)
        authorizationState = mapStatus(status)

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
        var fetchedAssets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetchedAssets.append(asset)
        }
        assets = fetchedAssets
        isLoading = false

        await loadMetadataCache()
        await syncMetadata()
    }

    func loadThumbnail(for asset: PHAsset) async {
        let identifier = asset.localIdentifier
        guard thumbnails[identifier] == nil else { return }

        let image = await service.requestImage(
            for: asset,
            targetSize: Self.thumbnailSize,
            contentMode: .aspectFill,
            options: nil
        )
        if let image {
            thumbnails[identifier] = image
        }
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
        } catch {
            errorMessage = "Failed to load metadata cache: \(error.localizedDescription)"
        }
    }

    func syncMetadata() async {
        guard let container = modelContainer, !assets.isEmpty else { return }

        isSyncingMetadata = true
        metadataSyncProgress = 0
        metadataSyncTotal = 0

        let assetsSnapshot = assets
        let viewModel = self
        let result: [String: MediaMetadata]? = await Task.detached {
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<MediaMetadata>()
            let existing: Set<String>
            do {
                let records = try context.fetch(descriptor)
                existing = Set(records.map(\.localIdentifier))
            } catch {
                return nil as [String: MediaMetadata]?
            }

            let toSync = assetsSnapshot.filter { !existing.contains($0.localIdentifier) }
            let total = toSync.count
            await MainActor.run { viewModel.metadataSyncTotal = total }

            var insertCount = 0
            for asset in toSync {
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
        }
        isSyncingMetadata = false
    }

    var filteredAssets: [PHAsset] {
        let filtered: [PHAsset]
        switch mediaFilter {
        case .all:
            filtered = assets
        case .photosOnly:
            filtered = assets.filter { $0.mediaType == .image }
        case .videosOnly:
            filtered = assets.filter { $0.mediaType == .video }
        }

        // The fetch already returns assets sorted by creationDate descending,
        // so skip re-sorting when that matches the current sort settings.
        if sortOption == .recordTime && sortOrder == .descending {
            return filtered
        }

        return filtered.sorted { a, b in
            let result: Bool
            switch sortOption {
            case .recordTime:
                let dateA = a.creationDate ?? .distantPast
                let dateB = b.creationDate ?? .distantPast
                result = dateA < dateB
            case .duration:
                result = a.duration < b.duration
            case .fileSize:
                let sizeA = metadataCache[a.localIdentifier]?.fileSize ?? 0
                let sizeB = metadataCache[b.localIdentifier]?.fileSize ?? 0
                result = sizeA < sizeB
            }
            return sortOrder == .ascending ? result : !result
        }
    }

    private func mapStatus(_ status: PHAuthorizationStatus) -> PhotoAuthorizationState {
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
}
