//
//  DemoPhotoLibraryService.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

#if SCREENSHOTS

import Photos
import AppKit

final class DemoPhotoLibraryService: PhotoLibraryServing {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        .authorized
    }

    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        .authorized
    }

    nonisolated func fetchAssets(with options: PHFetchOptions) -> PHFetchResult<PHAsset> {
        PHFetchResult<PHAsset>()
    }

    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?
    ) async -> NSImage? {
        nil
    }

    nonisolated func writeAssetResource(_ resource: PHAssetResource, toFileURL url: URL, options: PHAssetResourceRequestOptions?) async throws {
        // No-op in demo mode
    }
}

#endif
