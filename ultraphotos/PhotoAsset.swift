//
//  PhotoAsset.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import Photos

struct PhotoAsset: Identifiable, Sendable, Equatable {
    let id: String
    let creationDate: Date?
    let isVideo: Bool
    let duration: TimeInterval
    let pixelWidth: Int
    let pixelHeight: Int

    init(from phAsset: PHAsset) {
        self.id = phAsset.localIdentifier
        self.creationDate = phAsset.creationDate
        self.isVideo = phAsset.mediaType == .video
        self.duration = phAsset.duration
        self.pixelWidth = phAsset.pixelWidth
        self.pixelHeight = phAsset.pixelHeight
    }

    init(
        id: String,
        creationDate: Date?,
        isVideo: Bool,
        duration: TimeInterval,
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.id = id
        self.creationDate = creationDate
        self.isVideo = isVideo
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}
