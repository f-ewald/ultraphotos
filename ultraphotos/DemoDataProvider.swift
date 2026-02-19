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

    private static let gradientPalettes: [(start: (r: CGFloat, g: CGFloat, b: CGFloat), end: (r: CGFloat, g: CGFloat, b: CGFloat))] = [
        // Warm sunset
        (start: (0.98, 0.60, 0.45), end: (0.85, 0.35, 0.55)),
        // Ocean blue
        (start: (0.40, 0.73, 0.88), end: (0.22, 0.42, 0.72)),
        // Soft lavender
        (start: (0.75, 0.62, 0.90), end: (0.50, 0.38, 0.75)),
        // Mint fresh
        (start: (0.55, 0.88, 0.75), end: (0.30, 0.68, 0.65)),
        // Golden hour
        (start: (0.98, 0.82, 0.45), end: (0.92, 0.55, 0.35)),
        // Rose quartz
        (start: (0.92, 0.65, 0.72), end: (0.75, 0.42, 0.55)),
        // Sky blue
        (start: (0.55, 0.78, 0.95), end: (0.38, 0.55, 0.82)),
        // Sage green
        (start: (0.62, 0.80, 0.58), end: (0.38, 0.60, 0.42)),
        // Peach blush
        (start: (0.98, 0.75, 0.62), end: (0.90, 0.52, 0.48)),
        // Twilight purple
        (start: (0.58, 0.48, 0.82), end: (0.35, 0.28, 0.62)),
        // Coral reef
        (start: (0.95, 0.55, 0.50), end: (0.82, 0.38, 0.58)),
        // Teal dream
        (start: (0.42, 0.82, 0.82), end: (0.25, 0.58, 0.68)),
        // Dusty rose
        (start: (0.85, 0.62, 0.65), end: (0.65, 0.40, 0.50)),
        // Arctic blue
        (start: (0.68, 0.85, 0.95), end: (0.42, 0.62, 0.80)),
        // Warm amber
        (start: (0.95, 0.72, 0.38), end: (0.82, 0.48, 0.30)),
        // Lilac mist
        (start: (0.82, 0.72, 0.92), end: (0.60, 0.48, 0.75)),
        // Forest moss
        (start: (0.52, 0.75, 0.52), end: (0.32, 0.55, 0.38)),
        // Flamingo pink
        (start: (0.95, 0.58, 0.65), end: (0.80, 0.35, 0.48)),
        // Deep sea
        (start: (0.32, 0.62, 0.78), end: (0.18, 0.38, 0.58)),
        // Apricot
        (start: (0.98, 0.78, 0.55), end: (0.88, 0.58, 0.42)),
        // Wisteria
        (start: (0.70, 0.55, 0.85), end: (0.48, 0.35, 0.68)),
        // Seafoam
        (start: (0.50, 0.85, 0.78), end: (0.32, 0.65, 0.60)),
        // Mauve
        (start: (0.78, 0.58, 0.70), end: (0.58, 0.38, 0.52)),
        // Cerulean
        (start: (0.48, 0.70, 0.90), end: (0.30, 0.48, 0.72)),
    ]

    static func generateGradientImage(size: CGSize, identifier: String, index: Int) -> NSImage {
        let palette = gradientPalettes[index % gradientPalettes.count]
        let angle: CGFloat = CGFloat(index % 6) * 60.0

        let startColor = NSColor(red: palette.start.r, green: palette.start.g, blue: palette.start.b, alpha: 1.0)
        let endColor = NSColor(red: palette.end.r, green: palette.end.g, blue: palette.end.b, alpha: 1.0)

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
