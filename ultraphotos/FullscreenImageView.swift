//
//  FullscreenImageView.swift
//  ultraphotos
//
//  Created by Friedrich Ewald on 2/18/26.
//

import SwiftUI

struct FullscreenImageView: View {
    @Bindable var viewModel: PhotoGridViewModel
    @FocusState private var isFocused: Bool

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            if let image = viewModel.fullscreenImage {
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
            await viewModel.loadFullscreenImage()
        }
    }
}
