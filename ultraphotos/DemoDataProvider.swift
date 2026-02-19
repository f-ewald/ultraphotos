//
//  DemoDataProvider.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

#if SCREENSHOTS

import AppKit

enum DemoDataProvider {

    static func generateAssets() -> [PhotoAsset] {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2025, month: 12, day: 15))!

        var assets: [PhotoAsset] = []
        for i in 0..<24 {
            let isVideo = i % 5 == 0 // ~20% videos (indices 0, 5, 10, 15, 20)
            let date = calendar.date(byAdding: .hour, value: -i * 6, to: baseDate)

            let widths = [4032, 3024, 4000, 3840, 2048, 5472]
            let heights = [3024, 4032, 3000, 2160, 1536, 3648]
            let width = widths[i % widths.count]
            let height = heights[i % heights.count]

            let duration: TimeInterval = isVideo ? Double((i + 1) * 7) : 0

            assets.append(PhotoAsset(
                id: "demo-asset-\(i)",
                creationDate: date,
                isVideo: isVideo,
                duration: duration,
                pixelWidth: width,
                pixelHeight: height
            ))
        }
        return assets
    }

    static func populateThumbnailCache(_ cache: NSCache<NSString, NSImage>, for assets: [PhotoAsset], size: CGSize) {
        for (index, asset) in assets.enumerated() {
            let image = generateGradientImage(size: size, identifier: asset.id, index: index)
            cache.setObject(image, forKey: asset.id as NSString)
        }
    }

    static func generateGradientImage(size: CGSize, identifier: String, index: Int) -> NSImage {
        // Extract the numeric suffix from the identifier for deterministic hue
        let numericSuffix = identifier.split(separator: "-").last.flatMap { Int($0) } ?? 0
        let hue = CGFloat(numericSuffix % 24) / 24.0
        let angle: CGFloat = CGFloat(index % 6) * 60.0

        let startColor = NSColor(hue: hue, saturation: 0.7, brightness: 0.9, alpha: 1.0)
        let endColor = NSColor(hue: (hue + 0.3).truncatingRemainder(dividingBy: 1.0), saturation: 0.8, brightness: 0.6, alpha: 1.0)

        let image = NSImage(size: size)
        image.lockFocus()

        if let gradient = NSGradient(starting: startColor, ending: endColor) {
            gradient.draw(in: NSRect(origin: .zero, size: size), angle: angle)
        }

        image.unlockFocus()
        return image
    }
}

#endif
