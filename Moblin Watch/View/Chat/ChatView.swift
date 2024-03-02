import SwiftUI
import WrappingHStack

struct ChatView: View {
    @EnvironmentObject var model: Model

    private func fontSize() -> CGFloat {
        return CGFloat(model.settings.chat.fontSize)
    }

    var body: some View {
        if model.chatPosts.isEmpty {
            Text("Chat is empty.")
                .font(.system(size: fontSize()))
        } else {
            ForEach(model.chatPosts) { post in
                WrappingHStack(
                    alignment: .leading,
                    horizontalSpacing: 0,
                    verticalSpacing: 0,
                    fitContentWidth: true
                ) {
                    if model.settings.chat.timestampEnabled! {
                        Text(post.timestamp + " ")
                            .foregroundColor(.gray)
                    }
                    Text(post.user)
                        .foregroundColor(post.userColor)
                    Text(": ")
                    ForEach(post.segments) { segment in
                        if let text = segment.text {
                            Text(text + " ")
                        }
                        if let url = segment.url {
                            CacheAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                EmptyView()
                            }
                            .frame(height: CGFloat(fontSize() * 1.7))
                            Text(" ")
                        }
                    }
                }
            }
            .font(.system(size: fontSize()))
        }
    }
}
