import Collections
import SwiftUI

struct LineView: View {
    var user: String
    var userColor: String?
    var message: String
    var chat: SettingsChat

    private func usernameColor() -> Color {
        if let userColor, let colorNumber = Int(userColor.suffix(6), radix: 16) {
            let color = RgbColor(
                red: (colorNumber >> 16) & 0xFF,
                green: (colorNumber >> 8) & 0xFF,
                blue: colorNumber & 0xFF
            )
            return color.color()
        } else {
            return chat.usernameColor.color()
        }
    }

    private func backgroundColor() -> Color {
        if chat.backgroundColorEnabled {
            return chat.backgroundColor.color().opacity(0.6)
        } else {
            return .clear
        }
    }

    private func shadowColor() -> Color {
        if chat.shadowColorEnabled {
            return chat.shadowColor.color()
        } else {
            return .clear
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(user)
                .foregroundColor(usernameColor())
                .lineLimit(1)
                .padding([.leading], 5)
                .padding([.trailing], 0)
                .bold(chat.bold)
                .shadow(color: shadowColor(), radius: 0, x: 1.5, y: 1.5)
            Text(": ")
                .bold(chat.bold)
                .shadow(color: shadowColor(), radius: 0, x: 1.5, y: 1.5)
            Text(message)
                .foregroundColor(chat.messageColor.color())
                .bold(chat.bold)
                .lineLimit(2)
                .padding([.trailing], 5)
                .shadow(color: shadowColor(), radius: 0, x: 1.5, y: 1.5)
        }
        .font(.system(size: CGFloat(chat.fontSize)))
        .background(backgroundColor())
        .foregroundColor(.white)
        .cornerRadius(5)
    }
}

struct StreamOverlayChatView: View {
    @ObservedObject var model: Model

    func messageText() -> String {
        if !model.isChatConfigured() {
            return "Not configured"
        } else if model.isChatConnected() {
            return String(format: "%.2f m/s", model.chatPostsPerSecond)
        } else {
            return ""
        }
    }

    func messageColor() -> Color {
        if !model.isChatConfigured() {
            return .white
        } else if model.isChatConnected() {
            return .white
        } else {
            return .red
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Spacer()
                StreamOverlayIconAndTextView(
                    icon: "message",
                    text: messageText(),
                    color: messageColor()
                )
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(model.chatPosts, id: \.self) { post in
                        LineView(
                            user: post.user,
                            userColor: post.userColor,
                            message: post.message,
                            chat: model.database.chat!
                        )
                    }
                }
            }
            Spacer()
        }
    }
}
