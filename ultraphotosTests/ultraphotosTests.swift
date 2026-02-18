//
//  ultraphotosTests.swift
//  ultraphotosTests
//
//  Created by Friedrich Ewald on 2/18/26.
//

import Testing
import Photos
import AppKit
@testable import ultraphotos

final class MockPhotoLibraryService: PhotoLibraryServing {
    var stubbedAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    var stubbedRequestAuthorizationStatus: PHAuthorizationStatus = .authorized
    var stubbedFetchResult: PHFetchResult<PHAsset> = PHFetchResult<PHAsset>()
    var stubbedImage: NSImage? = NSImage()

    var authorizationStatusCallCount = 0
    var requestAuthorizationCallCount = 0
    var fetchAssetsCallCount = 0
    var requestImageCallCount = 0
    var lastRequestedTargetSize: CGSize?

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
}

struct PhotoGridViewModelTests {

    @Test func initialStateIsNotDetermined() {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock)

        #expect(viewModel.authorizationState == .notDetermined)
        #expect(viewModel.assets.isEmpty)
        #expect(viewModel.thumbnails.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func checkAuthorizationStatusMapsNotDetermined() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .notDetermined
        let viewModel = PhotoGridViewModel(service: mock)

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .notDetermined)
        #expect(mock.authorizationStatusCallCount == 1)
    }

    @Test func checkAuthorizationStatusMapsAuthorized() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .authorized
        let viewModel = PhotoGridViewModel(service: mock)

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .authorized)
    }

    @Test func checkAuthorizationStatusMapsLimited() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .limited
        let viewModel = PhotoGridViewModel(service: mock)

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .limited)
    }

    @Test func checkAuthorizationStatusMapsDenied() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .denied
        let viewModel = PhotoGridViewModel(service: mock)

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .denied)
    }

    @Test func checkAuthorizationStatusMapsRestricted() {
        let mock = MockPhotoLibraryService()
        mock.stubbedAuthorizationStatus = .restricted
        let viewModel = PhotoGridViewModel(service: mock)

        viewModel.checkAuthorizationStatus()

        #expect(viewModel.authorizationState == .restricted)
    }

    @Test func requestAuthorizationCallsServiceAndUpdatesState() async {
        let mock = MockPhotoLibraryService()
        mock.stubbedRequestAuthorizationStatus = .authorized
        let viewModel = PhotoGridViewModel(service: mock)

        await viewModel.requestAuthorization()

        #expect(mock.requestAuthorizationCallCount == 1)
        #expect(viewModel.authorizationState == .authorized)
    }

    @Test func requestAuthorizationDeniedDoesNotFetchAssets() async {
        let mock = MockPhotoLibraryService()
        mock.stubbedRequestAuthorizationStatus = .denied
        let viewModel = PhotoGridViewModel(service: mock)

        await viewModel.requestAuthorization()

        #expect(viewModel.authorizationState == .denied)
        #expect(mock.fetchAssetsCallCount == 0)
    }

    @Test func fetchAssetsSetsIsLoadingToFalseWhenDone() async {
        let mock = MockPhotoLibraryService()
        let viewModel = PhotoGridViewModel(service: mock)

        await viewModel.fetchAssets()

        #expect(viewModel.isLoading == false)
    }

    @Test func thumbnailSizeIs300x300() {
        #expect(PhotoGridViewModel.thumbnailSize == CGSize(width: 300, height: 300))
    }
}
