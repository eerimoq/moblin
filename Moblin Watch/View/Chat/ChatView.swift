import SwiftUI
import WrappingHStack

private struct LineView: View {
    @EnvironmentObject var model: Model
    let post: ChatPost
    let fontSize: CGFloat

    var body: some View {
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
            if post.isRedemption() {
                Text(" ")
            } else {
                Text(": ")
            }
            ForEach(post.segments) { segment in
                if let text = segment.text {
                    Text(text)
                }
                if let url = segment.url {
                    CacheImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .frame(height: fontSize * 1.5)
                    Text(" ")
                }
            }
        }
    }
}

private struct HighlightView: View {
    let image: String
    let name: String

    var body: some View {
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            Image(systemName: image)
            Text(" ")
            Text(name)
        }
    }
}

private struct NormalView: View {
    @EnvironmentObject var model: Model
    let post: ChatPost
    let fontSize: CGFloat

    var body: some View {
        if let highlight = post.highlight {
            HStack(spacing: 0) {
                Rectangle()
                    .frame(width: 3)
                    .foregroundColor(highlight.color)
                    .padding([.trailing], 3)
                VStack(alignment: .leading) {
                    HighlightView(image: highlight.image, name: highlight.title)
                    LineView(post: post, fontSize: fontSize)
                }
            }
        } else {
            LineView(post: post, fontSize: fontSize)
        }
    }
}

private struct RedLineView: View {
    var body: some View {
        Rectangle()
            .fill(.red)
            .frame(height: 1.5)
            .padding(2)
    }
}

private struct InfoView: View {
    @EnvironmentObject var model: Model
    let post: ChatPost

    var body: some View {
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

struct ChatView: View {
    @EnvironmentObject var model: Model

    private func fontSize() -> CGFloat {
        return CGFloat(model.settings.chat.fontSize)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                if model.chatPosts.isEmpty {
                    Text("Chat is empty.")
                        .font(.system(size: fontSize()))
                } else {
                    ForEach(model.chatPosts) { post in
                        if post.kind == .normal {
                            NormalView(post: post, fontSize: fontSize())
                        } else if post.kind == .redLine {
                            RedLineView()
                        } else {
                            InfoView(post: post)
                        }
                    }
                    .font(.system(size: fontSize()))
                }
            }
        }
    }
}
