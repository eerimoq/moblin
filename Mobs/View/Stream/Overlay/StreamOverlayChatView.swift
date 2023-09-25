import Collections
import SwiftUI

struct LineView: View {
    var user: String
    var message: String

    var body: some View {
        HStack {
            Text(user)
                .frame(width: 70, alignment: .leading)
                .lineLimit(1)
                .padding([.leading], 5)
            Text(message)
                .lineLimit(2)
                .padding([.trailing], 5)
        }
        .padding(0)
        .font(.system(size: 13))
        .background(Color(white: 0, opacity: 0.6))
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

struct StreamOverlayChatView: View {
    var posts: Deque<Post>

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(posts, id: \.self) { post in
                LineView(user: post.user, message: post.message)
            }
        }
    }
}
