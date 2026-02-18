//
//  PhotoLibraryService.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import Photos
import AppKit

protocol PhotoLibraryServing: Sendable {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus
    func fetchAssets(with options: PHFetchOptions) -> PHFetchResult<PHAsset>
    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?
    ) async -> NSImage?
}

final class PhotoLibraryService: PhotoLibraryServing {
    private let imageManager = PHCachingImageManager()

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: accessLevel)
    }

    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: accessLevel)
    }

    nonisolated func fetchAssets(with options: PHFetchOptions) -> PHFetchResult<PHAsset> {
        PHAsset.fetchAssets(with: options)
    }

    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?
    ) async -> NSImage? {
        await withCheckedContinuation { continuation in
            let requestOptions = options ?? PHImageRequestOptions()
            requestOptions.deliveryMode = .highQualityFormat
            requestOptions.isNetworkAccessAllowed = true
            requestOptions.isSynchronous = false

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: requestOptions
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
