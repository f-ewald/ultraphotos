//
//  PhotoThumbnailView.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import SwiftUI
import Photos

struct PhotoThumbnailView: View {
    let asset: PHAsset
    @Bindable var viewModel: PhotoGridViewModel
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = viewModel.thumbnails[asset.localIdentifier] {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay {
                        ProgressView()
                    }
            }

            if asset.mediaType == .video {
                Text(formattedDuration(asset.duration))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
        .cornerRadius(4)
        .task {
            await viewModel.loadThumbnail(for: asset)
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
