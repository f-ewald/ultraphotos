# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UltraPhotos is a native macOS application for analyzing metadata of photos stored in Apple Photos. It extracts and displays metadata such as file size, filename, location, and other EXIF/photo properties. Built with Swift, SwiftUI, and SwiftData, targeting macOS 26.2 and requiring Xcode 16+. Bundle identifier: `net.fewald.ultraphotos`.

## Build & Test Commands

```bash
# Build (Debug)
make build

# Build (Release)
make build-release

# Build with demo/screenshot data (uses SCREENSHOTS compilation condition)
make build-screenshots

# Run all tests (unit + UI)
make test

# Run unit tests only
make test-unit

# Run UI tests only
make test-ui

# Clean
make clean

# Run a single test (use xcodebuild directly)
xcodebuild -project ultraphotos.xcodeproj -scheme ultraphotos -only-testing:ultraphotosTests/ultraphotosTests/example test
```

## Architecture

The app follows an **MVVM pattern** with a protocol-based service layer.

- **Entry point:** `ultraphotosApp.swift` — sets up the `ModelContainer` for SwiftData and hosts the main `WindowGroup`.
- **Model (SwiftData):** `MediaMetadata` defined in `MediaMetadataSchemaV1.swift` — stores per-asset metadata (file size, creation date, duration, location). Uses `VersionedSchema` with a migration plan.
- **ViewModel:** `PhotoGridViewModel` (`@Observable`) — core state manager handling photo library authorization, asset fetching/filtering/sorting, metadata sync, thumbnail caching, selection, export, and deletion.
- **Service layer:** `PhotoLibraryService` implements `PhotoLibraryServing` protocol — wraps `PHPhotoLibrary` and `PHCachingImageManager`. The protocol enables dependency injection for testing and demo mode.
- **Settings:** `SettingsView` — accessible via the standard macOS Settings menu item (Cmd+,). Uses the built-in `Settings` scene.
- **UI layer:** SwiftUI views consuming `PhotoGridViewModel`.

## Key Conventions

- Every new feature must include corresponding test cases.
- Swift concurrency: `SWIFT_APPROACHABLE_CONCURRENCY` is enabled with `MainActor` as the default actor isolation.
- App Sandbox and Hardened Runtime are enabled. User-selected files are read-write (`com.apple.security.files.user-selected.read-write`).
- No external dependencies — pure Apple platform APIs only.

## Testing Patterns

- **Mock service:** Create a mock conforming to `PhotoLibraryServing` and inject it into `PhotoGridViewModel(service:)`.
- **In-memory SwiftData:** Use `ModelConfiguration(isStoredInMemoryOnly: true)` to create a test `ModelContainer` without touching disk.
- **Unit tests** use Swift Testing (`import Testing`, `@Test`, `#expect`). UI tests use XCTest.

## Compilation Conditions

- `SCREENSHOTS` — enables demo mode with synthetic data (`DemoPhotoLibraryService`, `DemoDataProvider`). Used for App Store screenshots. Build with `make build-screenshots`.
