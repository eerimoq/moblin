import SwiftUI

let chatEmoteScale: Float = 1.5

private let deletedColor = UIColor(Color.gray)

struct ChatLineStyle {
    var fontSize: CGFloat
    var borderColor: UIColor?
    var borderWidth: CGFloat = 0
    var backgroundColor: UIColor?
    var leadingPadding: CGFloat = 5
    var timestampColor: UIColor?
    var messageColor: UIColor = .white
    var meInUsernameColor = false
    var boldUsername = false
    var boldMessage = false
    var badges = false
    var sharedChatIcons = false
    var animatedEmotes = false
    var bigGifScale: Float?
    var linkify = false
    var highlightSymbolColor: UIColor?
    var highlightDefaultColor: Color = .white
    var nicknames = SettingsChatNicknames()
    var displayStyle: SettingsChatDisplayStyle = .username

    func content(items: [ChatLineItem], topAligned: Bool = false) -> ChatLineContent {
        ChatLineContent(items: items,
                        fontSize: fontSize,
                        borderColor: borderColor,
                        borderWidth: borderWidth,
                        backgroundColor: backgroundColor,
                        leadingPadding: leadingPadding,
                        topAligned: topAligned)
    }

    func emoteItem(url: URL, scale: Float = 1, deleted: Bool) -> ChatLineItem {
        .image(ChatLineImage(source: .url(url),
                             animated: animatedEmotes,
                             height: fontSize * CGFloat(chatEmoteScale * scale),
                             verticalPadding: borderColor != nil ? borderWidth : 0,
                             opacity: deleted ? 0.25 : 1))
    }

    func badgeItem(source: ChatImageSource, deleted: Bool) -> ChatLineItem {
        .image(ChatLineImage(source: source,
                             height: fontSize * 1.4,
                             horizontalPadding: 2,
                             verticalPadding: 2,
                             opacity: deleted ? 0.25 : 1))
    }

    func symbolItem(name: String, color: UIColor) -> ChatLineItem {
        .image(ChatLineImage(source: .symbol(name, fontSize, color)))
    }

    func textItem(text: String,
                  color: UIColor,
                  bold: Bool = false,
                  italic: Bool = false,
                  singleLine: Bool = false,
                  deleted: Bool) -> ChatLineItem
    {
        .text(text, ChatLineTextStyle(color: deleted ? deletedColor : color,
                                      bold: bold,
                                      italic: italic,
                                      strikethrough: deleted,
                                      singleLine: singleLine))
    }

    func messageItem(text: String,
                     color: UIColor,
                     bold: Bool = false,
                     italic: Bool = false,
                     deleted: Bool) -> ChatLineItem
    {
        guard linkify, let url = getHttpsUrl(text: text) else {
            return textItem(text: text, color: color, bold: bold, italic: italic, deleted: deleted)
        }
        guard !deleted else {
            return textItem(text: text, color: color, bold: bold, italic: italic, deleted: true)
        }
        var style = ChatLineTextStyle(color: .systemBlue, bold: bold, italic: italic)
        style.link = url
        return .text(text, style)
    }

    private func spaceItem() -> ChatLineItem {
        .text(" ", ChatLineTextStyle(color: .white))
    }

    func makeContent(post: ChatPost, platform: Bool, deleted: Bool) -> ChatLineContent {
        var items: [ChatLineItem] = []
        if let timestampColor {
            items.append(.text("\(post.timestamp) ",
                               ChatLineTextStyle(color: timestampColor, singleLine: true)))
        }
        if platform, let image = post.platform?.imageName() {
            items.append(badgeItem(source: .asset(image), deleted: deleted))
        }
        if sharedChatIcons, let iconUrl = post.sourceChannelIcon {
            items.append(badgeItem(source: .url(iconUrl), deleted: deleted))
        }
        if badges {
            for url in post.userBadges {
                items.append(badgeItem(source: .url(url), deleted: deleted))
            }
        }
        let usernameColor = post.userColor.uiColor()
        items.append(textItem(text: post.displayName(nicknames: nicknames, displayStyle: displayStyle),
                              color: usernameColor,
                              bold: boldUsername,
                              singleLine: true,
                              deleted: deleted))
        items.append(.text(post.isRedemption() ? " " : ": ", ChatLineTextStyle(color: .white)))
        let textColor = post.isAction && meInUsernameColor ? usernameColor : messageColor
        for segment in post.segments {
            if let text = segment.text {
                items.append(messageItem(text: text,
                                         color: textColor,
                                         bold: boldMessage,
                                         italic: post.isAction,
                                         deleted: deleted))
            }
            if let url = segment.url?.url(animated: animatedEmotes) {
                items.append(emoteItem(url: url, deleted: deleted))
                items.append(spaceItem())
            }
            if let bigGifScale, let url = segment.bigGifUrl?.url(animated: animatedEmotes) {
                items.append(emoteItem(url: url, scale: bigGifScale, deleted: deleted))
                items.append(spaceItem())
            }
        }
        return content(items: items, topAligned: post.isBigGif())
    }

    func makeHighlightContent(highlight: ChatHighlight,
                              titleSegments: [ChatPostSegment],
                              deleted: Bool) -> ChatLineContent
    {
        let color = UIColor(highlight.messageColor(defaultColor: highlightDefaultColor))
        let symbolColor = highlightSymbolColor ?? color
        var items: [ChatLineItem] = [
            symbolItem(name: highlight.image, color: symbolColor),
            .text(" ", ChatLineTextStyle(color: symbolColor)),
        ]
        for segment in titleSegments {
            if let text = segment.text {
                items.append(messageItem(text: text, color: color, deleted: deleted))
            }
            if let url = segment.url?.url(animated: animatedEmotes) {
                items.append(emoteItem(url: url, deleted: deleted))
            }
        }
        return content(items: items)
    }

    func makeHighlightImageContent(highlight: ChatHighlight) -> ChatLineContent {
        let color = UIColor(highlight.messageColor(defaultColor: highlightDefaultColor))
        return content(items: [symbolItem(name: highlight.image, color: color)])
    }
}
