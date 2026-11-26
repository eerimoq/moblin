import SwiftUI

struct FeatureVideoCardView: View {
    let video: FeatureVideo

    var body: some View {
        Link(destination: video.url()) {
            Color(.secondarySystemGroupedBackground)
                .aspectRatio(9 / 16, contentMode: .fit)
                .overlay {
                    Image(video.thumbnail)
                        .resizable()
                        .scaledToFill()
                }
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct FeatureVideosGridView: View {
    let videos: [FeatureVideo]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 15)], spacing: 15) {
            ForEach(videos) {
                FeatureVideoCardView(video: $0)
                    .buttonStyle(.borderless)
            }
        }
        .listRowBackground(Color.clear)
    }
}

struct FeatureVideosSectionView: View {
    let videos: [FeatureVideo]

    var body: some View {
        Section {
            FeatureVideosGridView(videos: videos)
        } header: {
            Text("Help and inspiration")
        }
    }
}
