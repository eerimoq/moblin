import AVFoundation
import SwiftUI

struct VideoPreviewItemView: UIViewRepresentable {
    let previewView: PreviewView

    func makeUIView(context _: Context) -> PreviewView {
        return previewView
    }

    func updateUIView(_: PreviewView, context _: Context) {}
}

private struct VideoPreviewItem: View {
    @ObservedObject var orientation: Orientation
    let name: String
    let previewView: PreviewView

    private func height() -> Double {
        if orientation.isPortrait {
            return 118
        } else {
            return 68
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            VideoPreviewItemView(previewView: previewView)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(height: height())
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.gray.opacity(0.5), lineWidth: 1)
                )
            Text(name)
                .font(.caption2)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

struct StreamOverlayRightVideoPreviewView: View {
    let model: Model
    @ObservedObject var orientation: Orientation
    @ObservedObject var videoPreview: VideoPreviewProvider

    private func height() -> Double {
        if orientation.isPortrait {
            return 140
        } else {
            return 90
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack {
                if videoPreview.feeds.isEmpty {
                    Text("No video feeds")
                        .padding([.leading], 30)
                        .foregroundStyle(.white)
                }
                ForEach(videoPreview.feeds) { feed in
                    VideoPreviewItem(
                        orientation: orientation,
                        name: feed.name,
                        previewView: feed.previewView
                    )
                }
            }
            .frame(height: height())
        }
        .scrollIndicators(.hidden)
        .padding(4)
        .background(backgroundColor)
        .cornerRadius(5)
    }
}
