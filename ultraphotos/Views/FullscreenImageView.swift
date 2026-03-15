//
//  FullscreenImageView.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import SwiftUI
import AVKit

struct FullscreenImageView: View {
    @Bindable var viewModel: PhotoGridViewModel
    @FocusState private var isFocused: Bool

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            if viewModel.isFullscreenVideo {
                if let player = viewModel.fullscreenPlayer {
                    VideoPlayerView(player: player)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            } else if let image = viewModel.fullscreenImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if viewModel.isLoadingFullscreenImage {
                ProgressView()
                    .controlSize(.large)
            }

            HStack {
                Button {
                    viewModel.navigateFullscreen(direction: .previous)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)

                Spacer()

                Button {
                    viewModel.navigateFullscreen(direction: .next)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            .opacity(isHovering ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)

            VStack {
                HStack {
                    Button {
                        viewModel.closeFullscreen()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                            Text("Back")
                        }
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Spacer()
            }
            .padding(16)
            .opacity(isHovering ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovering)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) {
            viewModel.closeFullscreen()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.navigateFullscreen(direction: .previous)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.navigateFullscreen(direction: .next)
            return .handled
        }
        .task(id: viewModel.fullscreenAssetIdentifier) {
            if viewModel.isFullscreenVideo {
                await viewModel.loadFullscreenVideo()
            } else {
                await viewModel.loadFullscreenImage()
            }
        }
    }
}
