import SwiftUI
import WrappingHStack

struct ChatView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if model.chatPosts.isEmpty {
            Text("Chat is empty.")
        } else {
            ForEach(model.chatPosts) { post in
                WrappingHStack(
                    alignment: .leading,
                    horizontalSpacing: 0,
                    verticalSpacing: 0,
                    fitContentWidth: true
                ) {
                    Text(post.timestamp + " ")
                        .foregroundColor(.gray)
                    Text(post.user)
                        .foregroundColor(post.userColor)
                    Text(": ")
                    ForEach(post.segments) { segment in
                        if let text = segment.text {
                            Text(text + " ")
                        }
                    }
                }
            }
        }
    }
}
