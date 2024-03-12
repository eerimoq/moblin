import SwiftUI
import WrappingHStack

struct ChatView: View {
    @EnvironmentObject var model: Model
    let width: CGFloat

    private func fontSize() -> CGFloat {
        return CGFloat(model.settings.chat.fontSize)
    }

    var body: some View {
        if model.chatPosts.isEmpty {
            Text("Chat is empty.")
                .font(.system(size: fontSize()))
        } else {
            ForEach(model.chatPosts) { post in
                if post.kind == .normal {
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
                                Text(text)
                            }
                            if let url = segment.url {
                                WatchCacheAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    EmptyView()
                                }
                                .frame(height: CGFloat(fontSize() * 1.5))
                                Text(" ")
                            }
                        }
                    }
                } else if post.kind == .redLine {
                    Rectangle()
                        .fill(.red)
                        .frame(width: width, height: 1.5)
                        .padding(2)
                } else {
                    WrappingHStack(
                        alignment: .leading,
                        horizontalSpacing: 0,
                        verticalSpacing: 0,
                        fitContentWidth: true
                    ) {
                        ForEach(post.segments) { segment in
                            if let text = segment.text {
                                Text(text + " ")
                            }
                        }
                    }
                    .italic()
                }
            }
            .font(.system(size: fontSize()))
        }
    }
}
