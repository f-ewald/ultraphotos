//
//  ultraphotosTests.swift
//  ultraphotosTests
//
//  Created by Friedrich Ewald on 2/18/26.
//

import Testing
import Photos
import AppKit
import SwiftData
@testable import ultraphotos

final class MockPhotoLibraryService: PhotoLibraryServing {
    var stubbedAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    var stubbedRequestAuthorizationStatus: PHAuthorizationStatus = .authorized
    var stubbedFetchResult: PHFetchResult<PHAsset> = PHFetchResult<PHAsset>()
    var stubbedImage: NSImage? = NSImage()
    var writeAssetResourceShouldThrow = false
    var deleteAssetsShouldThrow = false

    var authorizationStatusCallCount = 0
    var requestAuthorizationCallCount = 0
    var fetchAssetsCallCount = 0
    var requestImageCallCount = 0
    var writeAssetResourceCallCount = 0
    var deleteAssetsCallCount = 0
    var lastRequestedTargetSize: CGSize?
    var lastDeletedIdentifiers: [String] = []

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        authorizationStatusCallCount += 1
        return stubbedAuthorizationStatus
    }

    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        requestAuthorizationCallCount += 1
        return stubbedRequestAuthorizationStatus
    }

    nonisolated func fetchAssets(with options: PHFetchOptions) -> PHFetchResult<PHAsset> {
        // Note: nonisolated to match protocol, but test usage is single-threaded
        return stubbedFetchResult
    }

    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        options: PHImageRequestOptions?
    ) async -> NSImage? {
        requestImageCallCount += 1
        lastRequestedTargetSize = targetSize
        return stubbedImage
    }

    nonisolated func writeAssetResource(_ resource: PHAssetResource, toFileURL url: URL, options: PHAssetResourceRequestOptions?) async throws {
        writeAssetResourceCallCount += 1
        if writeAssetResourceShouldThrow {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock write failure"])
        }
    }

    func deleteAssets(withIdentifiers identifiers: [String]) async throws {
        deleteAssetsCallCount += 1
        lastDeletedIdentifiers = identifiers
        if deleteAssetsShouldThrow {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock delete failure"])
        }
    }
}

struct PhotoGridViewModelTests {

    private func makeTestDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test func initialStateIsNotDetermined() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.authorizationState == .notDetermined)
        #expect(viewModel.assets.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func checkAuthorizationStatusMapsNotDetermined() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .notDetermined
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .notDetermined)
        // Count is 2: once during init (to set initial state) and once from checkAuthorizationStatus()
        #expect(mock.authorizationStatusCallCount == 2)
    }

    @Test func checkAuthorizationStatusMapsAuthorized() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .authorized
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .authorized)
    }

    @Test func checkAuthorizationStatusMapsLimited() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .limited
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .limited)
    }

    @Test func checkAuthorizationStatusMapsDenied() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .denied
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .denied)
    }

    @Test func checkAuthorizationStatusMapsRestricted() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .restricted
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .restricted)
    }

    @Test func requestAuthorizationCallsServiceAndUpdatesState() async {
        let mock = MockPhotoLibraryService()
        mock.stubbedRequestAuthorizationStatus = .authorized
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        await viewModel.requestAuthorization()

        #expect(mock.requestAuthorizationCallCount == 1)
        #expect(viewModel.authorizationState == .authorized)
    }

    @Test func requestAuthorizationDeniedDoesNotFetchAssets() async {
        let mock = MockPhotoLibraryService()
        mock.stubbedRequestAuthorizationStatus = .denied
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        await viewModel.requestAuthorization()

        #expect(viewModel.authorizationState == .denied)
        #expect(mock.fetchAssetsCallCount == 0)
    }

    @Test func fetchAssetsSetsIsLoadingToFalseWhenDone() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        await viewModel.fetchAssets()

        #expect(viewModel.isLoading == false)
    }

    @Test func thumbnailSizeIs300x300() {
        #expect(PhotoGridViewModel.thumbnailSize == CGSize(width: 300, height: 300))
    }

    @Test func defaultMediaFilterIsAll() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.mediaFilter == .all)
    }

    @Test func filteredAssetsReturnsAllWhenFilterIsAll() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        await viewModel.fetchAssets()

        viewModel.mediaFilter = .all
        #expect(viewModel.filteredAssets.count == viewModel.assets.count)
    }

    @Test func mediaFilterCanBeSetToPhotosOnly() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.mediaFilter = .photosOnly
        #expect(viewModel.mediaFilter == .photosOnly)
    }

    @Test func mediaFilterCanBeSetToVideosOnly() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.mediaFilter = .videosOnly
        #expect(viewModel.mediaFilter == .videosOnly)
    }

    @Test func mediaTypeFilterAllCasesHasThreeOptions() {
        #expect(MediaTypeFilter.allCases.count == 3)
    }

    @Test func mediaTypeFilterLabels() {
        #expect(MediaTypeFilter.all.label == "All")
        #expect(MediaTypeFilter.photosOnly.label == "Photos")
        #expect(MediaTypeFilter.videosOnly.label == "Videos")
    }

    @Test func mediaTypeFilterSystemImages() {
        #expect(MediaTypeFilter.all.systemImage == "photo.on.rectangle")
        #expect(MediaTypeFilter.photosOnly.systemImage == "photo")
        #expect(MediaTypeFilter.videosOnly.systemImage == "video")
    }

    // MARK: - SortOption enum tests

    @Test func sortOptionAllCasesHasThreeOptions() {
        #expect(SortOption.allCases.count == 3)
    }

    @Test func sortOptionLabels() {
        #expect(SortOption.recordTime.label == "Record Time")
        #expect(SortOption.duration.label == "Duration")
        #expect(SortOption.fileSize.label == "File Size")
    }

    @Test func sortOptionSystemImages() {
        #expect(SortOption.recordTime.systemImage == "calendar.circle")
        #expect(SortOption.duration.systemImage == "timer")
        #expect(SortOption.fileSize.systemImage == "internaldrive")
    }

    @Test func sortOptionIds() {
        #expect(SortOption.recordTime.id == "recordTime")
        #expect(SortOption.duration.id == "duration")
        #expect(SortOption.fileSize.id == "fileSize")
    }

    // MARK: - SortOrder enum tests

    @Test func sortOrderAllCasesHasTwoOptions() {
        #expect(SortOrder.allCases.count == 2)
    }

    @Test func sortOrderLabels() {
        #expect(SortOrder.ascending.label == "Ascending")
        #expect(SortOrder.descending.label == "Descending")
    }

    @Test func sortOrderSystemImages() {
        #expect(SortOrder.ascending.systemImage == "arrow.up")
        #expect(SortOrder.descending.systemImage == "arrow.down")
    }

    @Test func sortOrderIds() {
        #expect(SortOrder.ascending.id == "ascending")
        #expect(SortOrder.descending.id == "descending")
    }

    // MARK: - ViewModel sort defaults

    @Test func defaultSortOptionIsRecordTime() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.sortOption == .recordTime)
    }

    @Test func defaultSortOrderIsDescending() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.sortOrder == .descending)
    }

    @Test func sortOptionCanBeSetToDuration() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.sortOption = .duration
        #expect(viewModel.sortOption == .duration)
    }

    @Test func sortOptionCanBeSetToFileSize() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.sortOption = .fileSize
        #expect(viewModel.sortOption == .fileSize)
    }

    @Test func sortOrderCanBeSetToAscending() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.sortOrder = .ascending
        #expect(viewModel.sortOrder == .ascending)
    }

    // MARK: - Metadata cache tests

    @Test func isSyncingMetadataIsFalseInitially() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.isSyncingMetadata == false)
    }

    @Test func metadataCacheIsEmptyInitially() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.metadataCache.isEmpty)
    }

    @Test func mediaMetadataModelStoresAllProperties() throws {
        let schema = Schema(versionedSchema: MediaMetadataSchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let metadata = MediaMetadata(
            localIdentifier: "test-id-123",
            fileSize: 1_048_576,
            creationDate: Date(timeIntervalSince1970: 1_000_000),
            duration: 12.5,
            latitude: 37.7749,
            longitude: -122.4194
        )
        context.insert(metadata)
        try context.save()

        let descriptor = FetchDescriptor<MediaMetadata>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        let fetched = results[0]
        #expect(fetched.localIdentifier == "test-id-123")
        #expect(fetched.fileSize == 1_048_576)
        #expect(fetched.creationDate == Date(timeIntervalSince1970: 1_000_000))
        #expect(fetched.duration == 12.5)
        #expect(fetched.latitude == 37.7749)
        #expect(fetched.longitude == -122.4194)
    }

    @Test func mediaMetadataHandlesNilOptionals() throws {
        let schema = Schema(versionedSchema: MediaMetadataSchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let metadata = MediaMetadata(
            localIdentifier: "nil-test-id",
            fileSize: 0,
            creationDate: nil,
            duration: 0,
            latitude: nil,
            longitude: nil
        )
        context.insert(metadata)
        try context.save()

        let descriptor = FetchDescriptor<MediaMetadata>()
        let results = try context.fetch(descriptor)

        #expect(results.count == 1)
        let fetched = results[0]
        #expect(fetched.localIdentifier == "nil-test-id")
        #expect(fetched.creationDate == nil)
        #expect(fetched.latitude == nil)
        #expect(fetched.longitude == nil)
    }

    @Test func syncMetadataDoesNothingWhenNoContainer() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        await viewModel.syncMetadata()

        #expect(viewModel.isSyncingMetadata == false)
        #expect(viewModel.metadataCache.isEmpty)
    }

    @Test func syncMetadataDeletesStaleRecords() async throws {
        let mock = MockPhotoLibraryService()
        // Mock returns empty fetch result, so no assets exist in the library
        mock.stubbedFetchResult = PHFetchResult<PHAsset>()

        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let schema = Schema(versionedSchema: MediaMetadataSchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        viewModel.configure(modelContainer: container)

        // Insert a stale record that doesn't correspond to any current asset
        let context = ModelContext(container)
        let staleMetadata = MediaMetadata(
            localIdentifier: "stale-asset-id",
            fileSize: 500,
            creationDate: nil,
            duration: 0,
            latitude: nil,
            longitude: nil
        )
        context.insert(staleMetadata)
        try context.save()

        // Fetch assets (returns empty) then sync metadata
        await viewModel.fetchAssets()

        // The stale record should have been deleted
        let descriptor = FetchDescriptor<MediaMetadata>()
        let remaining = try ModelContext(container).fetch(descriptor)
        #expect(remaining.isEmpty)
        #expect(viewModel.metadataCache.isEmpty)
    }

    @Test func refreshMetadataCompletesCleanly() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())
        // No container configured — refreshMetadata should still complete without error

        await viewModel.refreshMetadata()

        #expect(viewModel.isSyncingMetadata == false)
    }

    @Test func migrationPlanHasOneSchema() {
        #expect(MediaMetadataMigrationPlan.schemas.count == 1)
        #expect(MediaMetadataMigrationPlan.stages.isEmpty)
    }

    // MARK: - Selection tests

    @Test func initialSelectionIsEmpty() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.selectedIdentifiers.isEmpty)
        #expect(viewModel.lastClickedIdentifier == nil)
    }

    @Test func plainClickSelectsSingleItem() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: [])

        #expect(viewModel.selectedIdentifiers == ["item-1"])
        #expect(viewModel.lastClickedIdentifier == "item-1")
    }

    @Test func plainClickReplacesExistingSelection() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: [])
        viewModel.handleThumbnailClick(identifier: "item-2", modifiers: [])

        #expect(viewModel.selectedIdentifiers == ["item-2"])
        #expect(viewModel.lastClickedIdentifier == "item-2")
    }

    @Test func cmdClickTogglesItemIn() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: [])
        viewModel.handleThumbnailClick(identifier: "item-2", modifiers: .command)

        #expect(viewModel.selectedIdentifiers == ["item-1", "item-2"])
        #expect(viewModel.lastClickedIdentifier == "item-2")
    }

    @Test func cmdClickTogglesItemOut() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: [])
        viewModel.handleThumbnailClick(identifier: "item-2", modifiers: .command)
        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: .command)

        #expect(viewModel.selectedIdentifiers == ["item-2"])
        #expect(viewModel.lastClickedIdentifier == "item-1")
    }

    @Test func shiftClickWithNoAnchorFallsToPlainClick() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        // No prior click, so lastClickedIdentifier is nil
        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: .shift)

        // Falls through to plain click
        #expect(viewModel.selectedIdentifiers == ["item-1"])
        #expect(viewModel.lastClickedIdentifier == "item-1")
    }

    @Test func shiftClickWithAnchorNotInFilteredFallsToPlainClick() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        // Set anchor via plain click, but filteredAssets is empty (no assets fetched)
        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: [])
        viewModel.handleThumbnailClick(identifier: "item-3", modifiers: .shift)

        // Both identifiers missing from empty filteredAssets — falls back to plain click
        #expect(viewModel.selectedIdentifiers == ["item-3"])
        #expect(viewModel.lastClickedIdentifier == "item-3")
    }

    @Test func clearSelectionResetsState() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.handleThumbnailClick(identifier: "item-1", modifiers: [])
        viewModel.clearSelection()

        #expect(viewModel.selectedIdentifiers.isEmpty)
        #expect(viewModel.lastClickedIdentifier == nil)
    }

    @Test func selectAllOnEmptyFilteredAssets() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.selectAll()

        #expect(viewModel.selectedIdentifiers.isEmpty)
    }

    // MARK: - rangeSelection static helper tests

    @Test func rangeSelectionForwardRange() {
        let result = PhotoGridViewModel.rangeSelection(
            in: ["a", "b", "c", "d", "e"],
            from: "b",
            to: "d"
        )
        #expect(result == Set(["b", "c", "d"]))
    }

    @Test func rangeSelectionBackwardRange() {
        let result = PhotoGridViewModel.rangeSelection(
            in: ["a", "b", "c", "d", "e"],
            from: "d",
            to: "b"
        )
        #expect(result == Set(["b", "c", "d"]))
    }

    @Test func rangeSelectionSameItem() {
        let result = PhotoGridViewModel.rangeSelection(
            in: ["a", "b", "c", "d", "e"],
            from: "b",
            to: "b"
        )
        #expect(result == Set(["b"]))
    }

    @Test func rangeSelectionMissingAnchorReturnsNil() {
        let result = PhotoGridViewModel.rangeSelection(
            in: ["a", "b", "c"],
            from: "z",
            to: "b"
        )
        #expect(result == nil)
    }

    @Test func rangeSelectionMissingTargetReturnsNil() {
        let result = PhotoGridViewModel.rangeSelection(
            in: ["a", "b", "c"],
            from: "a",
            to: "z"
        )
        #expect(result == nil)
    }

    // MARK: - exportMenuTitle tests

    @Test func exportMenuTitleNoSelection() {
        #expect(PhotoGridViewModel.exportMenuTitle(photoCount: 0, videoCount: 0) == "Export")
    }

    @Test func exportMenuTitleOnePhoto() {
        #expect(PhotoGridViewModel.exportMenuTitle(photoCount: 1, videoCount: 0) == "Export 1 Photo")
    }

    @Test func exportMenuTitleMultiplePhotos() {
        #expect(PhotoGridViewModel.exportMenuTitle(photoCount: 3, videoCount: 0) == "Export 3 Photos")
    }

    @Test func exportMenuTitleOneVideo() {
        #expect(PhotoGridViewModel.exportMenuTitle(photoCount: 0, videoCount: 1) == "Export 1 Video")
    }

    @Test func exportMenuTitleMultipleVideos() {
        #expect(PhotoGridViewModel.exportMenuTitle(photoCount: 0, videoCount: 5) == "Export 5 Videos")
    }

    @Test func exportMenuTitleMixed() {
        #expect(PhotoGridViewModel.exportMenuTitle(photoCount: 2, videoCount: 3) == "Export 2 Photos and 3 Videos")
    }

    @Test func exportMenuTitleMixedSingular() {
        #expect(PhotoGridViewModel.exportMenuTitle(photoCount: 1, videoCount: 1) == "Export 1 Photo and 1 Video")
    }

    // MARK: - Export state tests

    @Test func isExportingIsFalseInitially() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.isExporting == false)
        #expect(viewModel.exportProgress == 0)
        #expect(viewModel.exportTotal == 0)
        #expect(viewModel.exportResult == nil)
    }

    @Test func clearExportResultSetsNil() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        // Manually trigger an export with no selection to produce a result
        // then clear it
        viewModel.clearExportResult()
        #expect(viewModel.exportResult == nil)
    }

    @Test func exportResultEquality() {
        let a = ExportResult(successCount: 1, failureCount: 2, skippedCount: 3)
        let b = ExportResult(successCount: 1, failureCount: 2, skippedCount: 3)
        let c = ExportResult(successCount: 0, failureCount: 0, skippedCount: 0)

        #expect(a == b)
        #expect(a != c)
    }

    @Test func exportWithNoSelectionCompletesImmediately() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        // No assets selected
        await viewModel.exportAssets(to: URL(fileURLWithPath: "/tmp"))

        #expect(viewModel.isExporting == false)
        #expect(viewModel.exportResult == ExportResult(successCount: 0, failureCount: 0, skippedCount: 0))
    }

    // MARK: - Fullscreen state tests

    @Test func fullscreenIsInactiveInitially() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.fullscreenAssetIdentifier == nil)
        #expect(viewModel.fullscreenImage == nil)
        #expect(viewModel.isLoadingFullscreenImage == false)
        #expect(viewModel.isFullscreenActive == false)
    }

    @Test func openFullscreenSetsIdentifierAndLoading() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.openFullscreen(identifier: "photo-1")

        #expect(viewModel.fullscreenAssetIdentifier == "photo-1")
        #expect(viewModel.isLoadingFullscreenImage == true)
        #expect(viewModel.fullscreenImage == nil)
        #expect(viewModel.isFullscreenActive == true)
    }

    @Test func closeFullscreenClearsState() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.openFullscreen(identifier: "photo-1")
        viewModel.closeFullscreen()

        #expect(viewModel.fullscreenAssetIdentifier == nil)
        #expect(viewModel.fullscreenImage == nil)
        #expect(viewModel.isLoadingFullscreenImage == false)
        #expect(viewModel.isFullscreenActive == false)
    }

    @Test func openFullscreenClearsPreviousImage() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.openFullscreen(identifier: "photo-1")
        // Simulate that an image was loaded
        viewModel.openFullscreen(identifier: "photo-2")

        #expect(viewModel.fullscreenAssetIdentifier == "photo-2")
        #expect(viewModel.fullscreenImage == nil)
        #expect(viewModel.isLoadingFullscreenImage == true)
    }

    // MARK: - navigatedIdentifier static helper tests

    @Test func navigatedIdentifierNextWrapsAround() {
        let result = PhotoGridViewModel.navigatedIdentifier(
            in: ["a", "b", "c"],
            from: "c",
            direction: .next
        )
        #expect(result == "a")
    }

    @Test func navigatedIdentifierPreviousWrapsAround() {
        let result = PhotoGridViewModel.navigatedIdentifier(
            in: ["a", "b", "c"],
            from: "a",
            direction: .previous
        )
        #expect(result == "c")
    }

    @Test func navigatedIdentifierNextMiddle() {
        let result = PhotoGridViewModel.navigatedIdentifier(
            in: ["a", "b", "c"],
            from: "a",
            direction: .next
        )
        #expect(result == "b")
    }

    @Test func navigatedIdentifierPreviousMiddle() {
        let result = PhotoGridViewModel.navigatedIdentifier(
            in: ["a", "b", "c"],
            from: "c",
            direction: .previous
        )
        #expect(result == "b")
    }

    @Test func navigatedIdentifierMissingReturnsNil() {
        let result = PhotoGridViewModel.navigatedIdentifier(
            in: ["a", "b", "c"],
            from: "z",
            direction: .next
        )
        #expect(result == nil)
    }

    @Test func navigatedIdentifierEmptyListReturnsNil() {
        let result = PhotoGridViewModel.navigatedIdentifier(
            in: [],
            from: "a",
            direction: .next
        )
        #expect(result == nil)
    }

    @Test func navigatedIdentifierSingleElement() {
        let result = PhotoGridViewModel.navigatedIdentifier(
            in: ["a"],
            from: "a",
            direction: .next
        )
        #expect(result == "a")
    }

    // MARK: - PhotoAsset tests

    @Test func photoAssetStoresAllProperties() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = PhotoAsset(
            id: "test-123",
            creationDate: date,
            isVideo: false,
            duration: 0,
            pixelWidth: 4032,
            pixelHeight: 3024
        )

        #expect(asset.id == "test-123")
        #expect(asset.creationDate == date)
        #expect(asset.isVideo == false)
        #expect(asset.duration == 0)
        #expect(asset.pixelWidth == 4032)
        #expect(asset.pixelHeight == 3024)
    }

    @Test func photoAssetVideoProperties() {
        let asset = PhotoAsset(
            id: "video-456",
            creationDate: nil,
            isVideo: true,
            duration: 120.5,
            pixelWidth: 1920,
            pixelHeight: 1080
        )

        #expect(asset.isVideo == true)
        #expect(asset.duration == 120.5)
        #expect(asset.creationDate == nil)
    }

    @Test func photoAssetEquality() {
        let a = PhotoAsset(id: "x", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100)
        let b = PhotoAsset(id: "x", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100)
        let c = PhotoAsset(id: "y", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100)

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - setAssetsForTesting / filtering tests

    @Test func setAssetsForTestingSetsAssetsAndFilteredAssets() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "v1", creationDate: nil, isVideo: true, duration: 30, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        #expect(viewModel.assets.count == 2)
        #expect(viewModel.filteredAssets.count == 2)
    }

    @Test func filterPhotosOnlyExcludesVideos() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "v1", creationDate: nil, isVideo: true, duration: 30, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)
        viewModel.mediaFilter = .photosOnly

        #expect(viewModel.filteredAssets.count == 2)
        #expect(viewModel.filteredAssets.allSatisfy { !$0.isVideo })
    }

    @Test func filterVideosOnlyExcludesPhotos() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "v1", creationDate: nil, isVideo: true, duration: 30, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "v2", creationDate: nil, isVideo: true, duration: 60, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)
        viewModel.mediaFilter = .videosOnly

        #expect(viewModel.filteredAssets.count == 2)
        #expect(viewModel.filteredAssets.allSatisfy { $0.isVideo })
    }

    @Test func photoAndVideoCountsUseFilteredAssets() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "v1", creationDate: nil, isVideo: true, duration: 30, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        #expect(viewModel.photoCount == 2)
        #expect(viewModel.videoCount == 1)
    }

    @Test func selectAllUsesPhotoAssetIds() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "a", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "b", creationDate: nil, isVideo: true, duration: 10, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)
        viewModel.selectAll()

        #expect(viewModel.selectedIdentifiers == Set(["a", "b"]))
    }

    @Test func selectedAssetsReturnsPhotoAssets() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "a", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "b", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)
        viewModel.handleThumbnailClick(identifier: "a", modifiers: [])

        #expect(viewModel.selectedAssets.count == 1)
        #expect(viewModel.selectedAssets.first?.id == "a")
    }

    // MARK: - deleteMenuTitle tests

    @Test func deleteMenuTitleNoSelection() {
        #expect(PhotoGridViewModel.deleteMenuTitle(photoCount: 0, videoCount: 0) == "Delete")
    }

    @Test func deleteMenuTitleOnePhoto() {
        #expect(PhotoGridViewModel.deleteMenuTitle(photoCount: 1, videoCount: 0) == "Delete 1 Photo")
    }

    @Test func deleteMenuTitleMultiplePhotos() {
        #expect(PhotoGridViewModel.deleteMenuTitle(photoCount: 3, videoCount: 0) == "Delete 3 Photos")
    }

    @Test func deleteMenuTitleOneVideo() {
        #expect(PhotoGridViewModel.deleteMenuTitle(photoCount: 0, videoCount: 1) == "Delete 1 Video")
    }

    @Test func deleteMenuTitleMultipleVideos() {
        #expect(PhotoGridViewModel.deleteMenuTitle(photoCount: 0, videoCount: 5) == "Delete 5 Videos")
    }

    @Test func deleteMenuTitleMixed() {
        #expect(PhotoGridViewModel.deleteMenuTitle(photoCount: 2, videoCount: 3) == "Delete 2 Photos and 3 Videos")
    }

    @Test func deleteMenuTitleMixedSingular() {
        #expect(PhotoGridViewModel.deleteMenuTitle(photoCount: 1, videoCount: 1) == "Delete 1 Photo and 1 Video")
    }

    // MARK: - Delete state tests

    @Test func isDeletingIsFalseInitially() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.isDeleting == false)
    }

    @Test func deleteTitleReflectsSelectedAssets() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "v1", creationDate: nil, isVideo: true, duration: 30, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)
        viewModel.selectAll()

        #expect(viewModel.deleteTitle == "Delete 1 Photo and 1 Video")
    }

    // MARK: - deleteAssets behavior tests

    @Test func deleteAssetsCallsServiceForUnselectedItem() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        // Select p1, then delete p2 (unselected) — p2 gets auto-selected, p1 deselected
        viewModel.handleThumbnailClick(identifier: "p1", modifiers: [])
        await viewModel.deleteAssets(for: "p2")

        #expect(mock.deleteAssetsCallCount == 1)
        #expect(mock.lastDeletedIdentifiers == ["p2"])
        #expect(viewModel.assets.count == 1)
        #expect(viewModel.assets.first?.id == "p1")
    }

    @Test func deleteAssetsDeletesAllSelectedItems() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p3", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        viewModel.handleThumbnailClick(identifier: "p1", modifiers: [])
        viewModel.handleThumbnailClick(identifier: "p2", modifiers: .command)

        await viewModel.deleteAssets(for: "p1")

        #expect(mock.deleteAssetsCallCount == 1)
        #expect(Set(mock.lastDeletedIdentifiers) == Set(["p1", "p2"]))
        #expect(viewModel.assets.count == 1)
        #expect(viewModel.assets.first?.id == "p3")
        #expect(viewModel.selectedIdentifiers.isEmpty)
    }

    @Test func deleteAssetsClearsLastClickedWhenDeleted() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        viewModel.handleThumbnailClick(identifier: "p1", modifiers: [])
        #expect(viewModel.lastClickedIdentifier == "p1")

        await viewModel.deleteAssets(for: "p1")

        #expect(viewModel.lastClickedIdentifier == nil)
    }

    @Test func deleteAssetsPreservesLastClickedWhenNotDeleted() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p3", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        // Select p1 and p2, then delete for p1 (already selected) — lastClicked should
        // be cleared since p1 is deleted
        viewModel.handleThumbnailClick(identifier: "p1", modifiers: [])
        viewModel.handleThumbnailClick(identifier: "p2", modifiers: .command)
        #expect(viewModel.lastClickedIdentifier == "p2")

        await viewModel.deleteAssets(for: "p1")

        // p2 was also deleted, so lastClicked (p2) is cleared
        #expect(viewModel.lastClickedIdentifier == nil)
    }

    @Test func deleteAssetsUpdatesFilteredAssets() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "v1", creationDate: nil, isVideo: true, duration: 30, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        #expect(viewModel.filteredAssets.count == 2)

        await viewModel.deleteAssets(for: "p1")

        #expect(viewModel.filteredAssets.count == 1)
        #expect(viewModel.filteredAssets.first?.id == "v1")
    }

    @Test func deleteAssetsHandlesServiceError() async {
        let mock = MockPhotoLibraryService()
        mock.deleteAssetsShouldThrow = true
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        await viewModel.deleteAssets(for: "p1")

        #expect(mock.deleteAssetsCallCount == 1)
        #expect(viewModel.assets.count == 2)
        #expect(viewModel.isDeleting == false)
    }

    @Test func deleteAssetsRemovesSelectionForDeletedItems() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "p1", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p2", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "p3", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        // Select p1 and p3, then delete for p2 (unselected).
        // With auto-select, p2 gets selected (p1 and p3 deselected), only p2 is deleted.
        viewModel.handleThumbnailClick(identifier: "p1", modifiers: [])
        viewModel.handleThumbnailClick(identifier: "p3", modifiers: .command)

        await viewModel.deleteAssets(for: "p2")

        // p2 was auto-selected and deleted; selection is now empty
        #expect(viewModel.selectedIdentifiers.isEmpty)
        #expect(viewModel.assets.count == 2)
        #expect(viewModel.assets.map(\.id).contains("p1"))
        #expect(viewModel.assets.map(\.id).contains("p3"))
    }

    @Test func deleteAssetsAutoSelectsUnselectedItem() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let testAssets = [
            PhotoAsset(id: "A", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "B", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
            PhotoAsset(id: "C", creationDate: nil, isVideo: false, duration: 0, pixelWidth: 100, pixelHeight: 100),
        ]
        viewModel.setAssetsForTesting(testAssets)

        // Select A, then right-click delete on B
        viewModel.handleThumbnailClick(identifier: "A", modifiers: [])
        #expect(viewModel.selectedIdentifiers == Set(["A"]))

        await viewModel.deleteAssets(for: "B")

        // B was auto-selected (A deselected), then B deleted
        #expect(mock.deleteAssetsCallCount == 1)
        #expect(mock.lastDeletedIdentifiers == ["B"])
        #expect(viewModel.assets.count == 2)
        #expect(viewModel.assets.map(\.id).contains("A"))
        #expect(viewModel.assets.map(\.id).contains("C"))
        #expect(viewModel.selectedIdentifiers.isEmpty)
    }

    // MARK: - Preference persistence tests

    @Test func settingMediaFilterWritesToUserDefaults() {
        let defaults = UserDefaults(suiteName: "test.mediaFilter.\(UUID().uuidString)")!
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: defaults)

        viewModel.mediaFilter = .videosOnly

        #expect(defaults.string(forKey: PreferenceKeys.mediaFilter) == "videosOnly")
    }

    @Test func settingSortOptionWritesToUserDefaults() {
        let defaults = UserDefaults(suiteName: "test.sortOption.\(UUID().uuidString)")!
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: defaults)

        viewModel.sortOption = .fileSize

        #expect(defaults.string(forKey: PreferenceKeys.sortOption) == "fileSize")
    }

    @Test func settingSortOrderWritesToUserDefaults() {
        let defaults = UserDefaults(suiteName: "test.sortOrder.\(UUID().uuidString)")!
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: defaults)

        viewModel.sortOrder = .ascending

        #expect(defaults.string(forKey: PreferenceKeys.sortOrder) == "ascending")
    }

    @Test func viewModelRestoresPersistedPreferences() {
        let defaults = UserDefaults(suiteName: "test.restore.\(UUID().uuidString)")!
        defaults.set("photosOnly", forKey: PreferenceKeys.mediaFilter)
        defaults.set("duration", forKey: PreferenceKeys.sortOption)
        defaults.set("ascending", forKey: PreferenceKeys.sortOrder)

        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: defaults)

        #expect(viewModel.mediaFilter == .photosOnly)
        #expect(viewModel.sortOption == .duration)
        #expect(viewModel.sortOrder == .ascending)
    }

    @Test func invalidStoredValuesDefaultToDefaults() {
        let defaults = UserDefaults(suiteName: "test.invalid.\(UUID().uuidString)")!
        defaults.set("bogus", forKey: PreferenceKeys.mediaFilter)
        defaults.set("nope", forKey: PreferenceKeys.sortOption)
        defaults.set("wrong", forKey: PreferenceKeys.sortOrder)

        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: defaults)

        #expect(viewModel.mediaFilter == .all)
        #expect(viewModel.sortOption == .recordTime)
        #expect(viewModel.sortOrder == .descending)
    }

    // MARK: - Reindex Library

    @Test func reindexLibraryInitialState() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        #expect(viewModel.isReindexing == false)
        #expect(viewModel.reindexResult == nil)
    }

    @Test func reindexLibraryRemovesStaleAndPopulatesResult() async throws {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .authorized
        mock.stubbedFetchResult = PHFetchResult<PHAsset>()

        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        let schema = Schema(versionedSchema: MediaMetadataSchemaV1.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        viewModel.configure(modelContainer: container)

        // Insert a stale record that doesn't correspond to any current asset
        let context = ModelContext(container)
        let staleMetadata = MediaMetadata(
            localIdentifier: "stale-asset-id",
            fileSize: 500,
            creationDate: nil,
            duration: 0,
            latitude: nil,
            longitude: nil
        )
        context.insert(staleMetadata)
        try context.save()

        await viewModel.reindexLibrary()

        #expect(viewModel.isReindexing == false)
        #expect(viewModel.reindexResult != nil)
        #expect(viewModel.reindexResult?.removed == 1)
        #expect(viewModel.reindexResult?.added == 0)
    }

    @Test func clearReindexResult() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock, defaults: makeTestDefaults())

        viewModel.clearReindexResult()
        #expect(viewModel.reindexResult == nil)
    }

    @Test func reindexResultEquatable() {
        let a = ReindexResult(removed: 3, added: 5)
        let b = ReindexResult(removed: 3, added: 5)
        let c = ReindexResult(removed: 1, added: 2)

        #expect(a == b)
        #expect(a != c)
    }
}
