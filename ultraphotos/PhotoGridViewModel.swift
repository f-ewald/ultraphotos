//
//  PhotoGridViewModel.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import Photos
import AppKit
import Observation

enum PhotoAuthorizationState {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
}

@Observable
final class PhotoGridViewModel {
    static let thumbnailSize = CGSize(width: 300, height: 300)

    private(set) var authorizationState: PhotoAuthorizationState = .notDetermined
    private(set) var assets: [PHAsset] = []
    private(set) var thumbnails: [String: NSImage] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: PhotoLibraryServing

    init(service: PhotoLibraryServing = PhotoLibraryService()) {
        self.service = service
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
