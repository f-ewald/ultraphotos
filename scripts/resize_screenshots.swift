#!/usr/bin/env swift

import AppKit
import Foundation
import ImageIO

let targetSizes: [(width: Int, height: Int)] = [
    (1280, 800),
    (1440, 900),
    (2560, 1600),
    (2880, 1800),
]

let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "tif", "heic", "bmp", "gif"]

let screenshotsDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("screenshots")
let outputDir = screenshotsDir.appendingPathComponent("resized")

// Check that screenshots/ exists
guard FileManager.default.fileExists(atPath: screenshotsDir.path) else {
    fputs("Error: screenshots/ directory not found\n", stderr)
    exit(1)
}

// Gather image files
let contents = try FileManager.default.contentsOfDirectory(
    at: screenshotsDir,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
)
let imageFiles = contents.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }

guard !imageFiles.isEmpty else {
    fputs("Warning: no image files found in screenshots/\n", stderr)
    exit(0)
}

// Create output directory
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

/// Center-crop the image to 16:10 aspect ratio, then resize to the target dimensions.
func processImage(source: CGImage, targetWidth: Int, targetHeight: Int) -> CGImage? {
    let srcW = source.width
    let srcH = source.height

    // Compute crop rect to achieve 16:10 (same as target aspect ratio)
    let targetAspect = Double(targetWidth) / Double(targetHeight)
    let srcAspect = Double(srcW) / Double(srcH)

    let cropRect: CGRect
    if srcAspect > targetAspect {
        // Source is wider than 16:10 — crop sides
        let newW = Int(Double(srcH) * targetAspect)
        let xOffset = (srcW - newW) / 2
        cropRect = CGRect(x: xOffset, y: 0, width: newW, height: srcH)
    } else if srcAspect < targetAspect {
        // Source is taller than 16:10 — crop top/bottom
        let newH = Int(Double(srcW) / targetAspect)
        let yOffset = (srcH - newH) / 2
        cropRect = CGRect(x: 0, y: yOffset, width: srcW, height: newH)
    } else {
        cropRect = CGRect(x: 0, y: 0, width: srcW, height: srcH)
    }

    guard let cropped = source.cropping(to: cropRect) else { return nil }

    // Check for upscaling
    if cropped.width < targetWidth || cropped.height < targetHeight {
        fputs(
            "Warning: upscaling \(cropped.width)x\(cropped.height) -> \(targetWidth)x\(targetHeight)\n",
            stderr)
    }

    // Resize via CGContext
    let colorSpace = cropped.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    guard
        let ctx = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else { return nil }

    ctx.interpolationQuality = .high
    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
    return ctx.makeImage()
}

/// Write a CGImage as PNG to the given URL.
func writePNG(image: CGImage, to url: URL) -> Bool {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    do {
        try data.write(to: url)
        return true
    } catch {
        fputs("Error writing \(url.path): \(error)\n", stderr)
        return false
    }
}

var hasError = false

for file in imageFiles {
    let basename = file.deletingPathExtension().lastPathComponent

    guard let imageSource = CGImageSourceCreateWithURL(file as CFURL, nil),
        let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    else {
        fputs("Error: could not load image \(file.lastPathComponent)\n", stderr)
        hasError = true
        continue
    }

    print("Processing \(file.lastPathComponent) (\(sourceImage.width)x\(sourceImage.height))")

    for size in targetSizes {
        guard let result = processImage(source: sourceImage, targetWidth: size.width, targetHeight: size.height)
        else {
            fputs("Error: failed to process \(file.lastPathComponent) at \(size.width)x\(size.height)\n", stderr)
            hasError = true
            continue
        }

        let outURL = outputDir.appendingPathComponent("\(basename)_\(size.width)x\(size.height).png")
        if writePNG(image: result, to: outURL) {
            print("  -> \(outURL.lastPathComponent)")
        } else {
            hasError = true
        }
    }
}

exit(hasError ? 1 : 0)
