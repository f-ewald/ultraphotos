PROJECT = ultraphotos.xcodeproj
SCHEME = ultraphotos
BUILD_DIR = build

.PHONY: build build-release build-screenshots resize-screenshots test test-unit test-ui clean

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug build

build-release:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release build

build-screenshots:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG SCREENSHOTS' build
	@echo "App bundle created at: $(BUILD_DIR)/Build/Products/Debug/$(SCHEME).app"

test: test-unit test-ui

test-unit:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -only-testing:ultraphotosTests test

test-ui:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -only-testing:ultraphotosUITests test

resize-screenshots:
	swift scripts/resize_screenshots.swift

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
