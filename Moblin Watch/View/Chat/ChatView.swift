import Collections
import SwiftUI
import WrappingHStack

class Chat: ObservableObject {
    @Published var posts = Deque<ChatPost>()
}

private struct LineView: View {
    @ObservedObject var chatSettings: WatchSettingsChat
    let post: ChatPost

    var body: some View {
        WrappingHStack(
            alignment: .leading,
            horizontalSpacing: 0,
            verticalSpacing: 0,
            fitContentWidth: true
        ) {
            if chatSettings.timestampEnabled {
                Text(post.timestamp + " ")
                    .foregroundStyle(.gray)
            }
            if chatSettings.badges {
                ForEach(post.userBadges, id: \.self) { url in
                    CacheImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(2)
                    .frame(height: CGFloat(chatSettings.fontSize * 1.3))
                }
            }
            Text(post.displayName)
                .foregroundStyle(post.userColor)
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
                    .frame(height: CGFloat(chatSettings.fontSize) * 1.5)
                    Text(" ")
                }
            }
        }
    }
}

private struct HighlightView: View {
    let image: String
    let name: String
    let color: Color

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
        .foregroundStyle(color)
    }
}

private struct NormalView: View {
    @ObservedObject var chatSettings: WatchSettingsChat
    let post: ChatPost

    func highlightColor(highlight: ChatPostHighlight) -> Color {
        if highlight.kind == .reply {
            return .gray
        } else {
            return .white
        }
    }

    var body: some View {
        if let highlight = post.highlight {
            HStack(spacing: 0) {
                Rectangle()
                    .frame(width: 3)
                    .foregroundStyle(highlight.barColor)
                    .padding([.trailing], 3)
                VStack(alignment: .leading) {
                    HighlightView(image: highlight.image,
                                  name: highlight.title,
                                  color: highlightColor(highlight: highlight))
                    LineView(chatSettings: chatSettings, post: post)
                }
            }
        } else {
            LineView(chatSettings: chatSettings, post: post)
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
    @ObservedObject var chatSettings: WatchSettingsChat
    @ObservedObject var chat: Chat

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                if chat.posts.isEmpty {
                    Text("Chat is empty.")
                } else {
                    ForEach(chat.posts) { post in
                        if post.kind == .normal {
                            NormalView(chatSettings: chatSettings, post: post)
                        } else if post.kind == .redLine {
                            RedLineView()
                        } else {
                            InfoView(post: post)
                        }
                    }
                }
            }
            .font(.system(size: CGFloat(chatSettings.fontSize)))
        }
    }
}
