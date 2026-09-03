import SwiftUI

struct ChatGifView: View {
    let url: URL
    let animated: Bool
    let height: CGFloat

    var body: some View {
        if animated {
            AnimatedEmoteView(url: url)
                .frame(height: height)
        } else {
            CacheAsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                EmptyView()
            }
            .frame(height: height)
        }
    }
}
