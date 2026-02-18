# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UltraPhotos is a native macOS application for analyzing metadata of photos stored in Apple Photos. It extracts and displays metadata such as file size, filename, location, and other EXIF/photo properties. Built with Swift, SwiftUI, and SwiftData, targeting macOS 26.2 and requiring Xcode 16+. Bundle identifier: `net.fewald.ultraphotos`.

## Build & Test Commands

```bash
# Build (Debug)
xcodebuild -project ultraphotos.xcodeproj -scheme ultraphotos -configuration Debug build

# Build (Release)
xcodebuild -project ultraphotos.xcodeproj -scheme ultraphotos -configuration Release build

# Run all tests (unit + UI)
xcodebuild -project ultraphotos.xcodeproj -scheme ultraphotos test

# Run unit tests only
xcodebuild -project ultraphotos.xcodeproj -scheme ultraphotos -only-testing:ultraphotosTests test

# Run UI tests only
xcodebuild -project ultraphotos.xcodeproj -scheme ultraphotos -only-testing:ultraphotosUITests test

# Run a single test
xcodebuild -project ultraphotos.xcodeproj -scheme ultraphotos -only-testing:ultraphotosTests/ultraphotosTests/example test
```

## Architecture

- **Entry point:** `ultraphotosApp.swift` — sets up the `ModelContainer` for SwiftData and hosts the main `WindowGroup`.
- **Data layer:** SwiftData with `@Model` classes (currently `Item`). The model container is configured with on-disk persistence and injected via `.modelContainer()`.
- **UI layer:** SwiftUI views using `@Query` for reactive data fetching and `@Environment(\.modelContext)` for mutations.
- **Testing:** Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`). UI tests use XCTest.

## Key Conventions

- Every new feature must include corresponding test cases.
- Swift concurrency: `SWIFT_APPROACHABLE_CONCURRENCY` is enabled with `MainActor` as the default actor isolation.
- App Sandbox and Hardened Runtime are enabled. User-selected files are read-only.
- No external dependencies — pure Apple platform APIs only.
