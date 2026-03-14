//
//  MediaMetadataSchemaV1.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import Foundation
import SwiftData

enum MediaMetadataSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [MediaMetadata.self]
    }

    @Model
    final class MediaMetadata {
        @Attribute(.unique) var localIdentifier: String
        var fileSize: Int64
        var creationDate: Date?
        var duration: Double
        var latitude: Double?
        var longitude: Double?

        init(
            localIdentifier: String,
            fileSize: Int64,
            creationDate: Date?,
            duration: Double,
            latitude: Double?,
            longitude: Double?
        ) {
            self.localIdentifier = localIdentifier
            self.fileSize = fileSize
            self.creationDate = creationDate
            self.duration = duration
            self.latitude = latitude
            self.longitude = longitude
        }
    }
}

enum MediaMetadataMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MediaMetadataSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

typealias MediaMetadata = MediaMetadataSchemaV1.MediaMetadata
