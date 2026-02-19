//
//  PhotoThumbnailView.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import SwiftUI

struct PhotoThumbnailView: View {
    let asset: PhotoAsset
    @Bindable var viewModel: PhotoGridViewModel
    let size: CGFloat
    @State private var image: NSImage?

    private var isSelected: Bool {
        viewModel.selectedIdentifiers.contains(asset.id)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay {
                        ProgressView()
                    }
            }

            VStack {
                HStack {
                    Spacer()
                    if let date = asset.creationDate {
                        Text(date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year(.defaultDigits)))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Spacer()
                HStack {
                    if asset.isVideo {
                        Text(formattedDuration(asset.duration))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                    if let cached = viewModel.metadataCache[asset.id] {
                        Text(formattedFileSize(cached.fileSize))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(4)
        }
        .overlay {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.15))
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open in Apple Photos") {
                viewModel.handleThumbnailClick(identifier: asset.id, modifiers: [])
                viewModel.openInPhotos(identifier: asset.id)
            }
        }
        .onTapGesture(count: 2) {
            viewModel.openFullscreen(identifier: asset.id)
        }
        .onTapGesture(count: 1) {
            let modifiers = NSApp.currentEvent?.modifierFlags
                .intersection(.deviceIndependentFlagsMask) ?? []
            viewModel.handleThumbnailClick(
                identifier: asset.id,
                modifiers: modifiers
            )
        }
        .task {
            image = await viewModel.loadThumbnail(for: asset.id)
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
