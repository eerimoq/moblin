import CoreText
import SwiftUI

struct ChatLineTextStyle: Equatable {
    var color: UIColor
    var bold = false
    var italic = false
    var strikethrough = false
    var singleLine = false
    var link: URL?
}

struct ChatLineImage: Equatable {
    let source: ChatImageSource
    var animated = true
    var height: CGFloat?
    var horizontalPadding: CGFloat = 0
    var verticalPadding: CGFloat = 0
    var opacity: CGFloat = 1
}

enum ChatLineItem: Equatable {
    case text(String, ChatLineTextStyle)
    case image(ChatLineImage)
}

struct ChatLineContent: Equatable {
    var items: [ChatLineItem]
    var fontSize: CGFloat
    var borderColor: UIColor?
    var borderWidth: CGFloat = 0
    var backgroundColor: UIColor?
    var leadingPadding: CGFloat = 0
    var topAligned = false
}

private let strikethroughKey = NSAttributedString.Key("moblinChatLineStrikethrough")
private let imageIndexKey = NSAttributedString.Key("moblinChatLineImageIndex")
private let linkKey = NSAttributedString.Key("moblinChatLineLink")
private let runDelegateKey = NSAttributedString.Key(kCTRunDelegateAttributeName as String)

private final class ImageRunMetrics {
    let ascent: CGFloat
    let descent: CGFloat
    let width: CGFloat

    init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
        self.ascent = ascent
        self.descent = descent
        self.width = width
    }

    func makeRunDelegate() -> CTRunDelegate? {
        var callbacks = CTRunDelegateCallbacks(
            version: kCTRunDelegateCurrentVersion,
            dealloc: { _ in },
            getAscent: { Unmanaged<ImageRunMetrics>.fromOpaque($0).takeUnretainedValue().ascent },
            getDescent: { Unmanaged<ImageRunMetrics>.fromOpaque($0).takeUnretainedValue().descent },
            getWidth: { Unmanaged<ImageRunMetrics>.fromOpaque($0).takeUnretainedValue().width }
        )
        return CTRunDelegateCreate(&callbacks, Unmanaged.passUnretained(self).toOpaque())
    }
}

private struct LayoutLine {
    let line: CTLine
    let strokeLine: CTLine?
    let baseline: CGFloat
}

private struct ChatLineLayout {
    let availableWidth: CGFloat
    let sizesVersion: Int
    let hasUnknownImageSize: Bool
    let size: CGSize
    let lines: [LayoutLine]
    let images: [ChatLineImage]
    let imageFrames: [CGRect]
    let metrics: [ImageRunMetrics]
}

private func makeFont(size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
    let font = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    guard italic else {
        return font
    }
    var traits: UIFontDescriptor.SymbolicTraits = [.traitItalic]
    if bold {
        traits.insert(.traitBold)
    }
    guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else {
        return font
    }
    return UIFont(descriptor: descriptor, size: size)
}

@MainActor
private func makeLayout(content: ChatLineContent, availableWidth: CGFloat) -> ChatLineLayout {
    let player = EmotesPlayer.shared
    let sizesVersion = player.sizesVersion
    let baseFont = UIFont.systemFont(ofSize: content.fontSize)
    let fontAscent = baseFont.ascender
    let fontDescent = -baseFont.descender
    let string = NSMutableAttributedString()
    var metrics: [ImageRunMetrics] = []
    var images: [ChatLineImage] = []
    var hasUnknownImageSize = false
    for item in content.items {
        switch item {
        case let .text(text, style):
            var text = text
            if style.singleLine {
                text = text.replacingOccurrences(of: " ", with: "\u{00A0}")
            }
            var attributes: [NSAttributedString.Key: Any] = [
                .font: makeFont(size: content.fontSize, bold: style.bold, italic: style.italic),
                .foregroundColor: style.color,
                strikethroughKey: style.strikethrough,
            ]
            if let link = style.link {
                attributes[linkKey] = link
            }
            string.append(NSAttributedString(string: text, attributes: attributes))
        case let .image(image):
            var contentWidth: CGFloat = 0
            var contentHeight: CGFloat = 0
            if let size = player.size(source: image.source), size.width > 0, size.height > 0 {
                if let height = image.height {
                    contentHeight = max(height - 2 * image.verticalPadding, 0)
                    contentWidth = contentHeight * size.width / size.height
                } else {
                    contentWidth = size.width
                    contentHeight = size.height
                }
            } else {
                hasUnknownImageSize = true
            }
            let width = contentWidth + 2 * image.horizontalPadding
            let height = contentHeight + 2 * image.verticalPadding
            let ascent = if content.topAligned {
                fontAscent
            } else {
                (height + fontAscent - fontDescent) / 2
            }
            let imageMetrics = ImageRunMetrics(ascent: ascent, descent: height - ascent, width: width)
            metrics.append(imageMetrics)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                imageIndexKey: images.count,
            ]
            if let delegate = imageMetrics.makeRunDelegate() {
                attributes[runDelegateKey] = delegate
            }
            string.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
            images.append(image)
        }
    }
    var strokeTypesetter: CTTypesetter?
    if let borderColor = content.borderColor, content.borderWidth > 0 {
        let strokeString = NSMutableAttributedString(attributedString: string)
        strokeString.addAttributes([
            .strokeColor: borderColor,
            .strokeWidth: 200 * content.borderWidth / content.fontSize,
        ], range: NSRange(location: 0, length: strokeString.length))
        strokeTypesetter = CTTypesetterCreateWithAttributedString(strokeString)
    }
    let typesetter = CTTypesetterCreateWithAttributedString(string)
    let textWidth = max(availableWidth - content.leadingPadding, 1)
    var lines: [LayoutLine] = []
    var imageFrames = [CGRect](repeating: .zero, count: images.count)
    var maxLineWidth: CGFloat = 0
    var y: CGFloat = 0
    var start = 0
    let length = string.length
    while start < length {
        var count = CTTypesetterSuggestLineBreak(typesetter, start, Double(textWidth))
        if count <= 0 {
            count = length - start
        }
        let range = CFRange(location: start, length: count)
        let line = CTTypesetterCreateLine(typesetter, range)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        let baseline = y + ascent
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
            guard let index = attributes[imageIndexKey] as? Int, index < images.count else {
                continue
            }
            let image = images[index]
            let imageMetrics = metrics[index]
            let x = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, nil)
            imageFrames[index] = CGRect(
                x: content.leadingPadding + x + image.horizontalPadding,
                y: baseline - imageMetrics.ascent + image.verticalPadding,
                width: imageMetrics.width - 2 * image.horizontalPadding,
                height: imageMetrics.ascent + imageMetrics.descent - 2 * image.verticalPadding
            )
        }
        lines.append(LayoutLine(line: line,
                                strokeLine: strokeTypesetter.map { CTTypesetterCreateLine($0, range) },
                                baseline: baseline))
        maxLineWidth = max(maxLineWidth, min(lineWidth, textWidth))
        y = baseline + descent
        start += count
    }
    return ChatLineLayout(availableWidth: availableWidth,
                          sizesVersion: sizesVersion,
                          hasUnknownImageSize: hasUnknownImageSize,
                          size: CGSize(width: ceil(content.leadingPadding + maxLineWidth), height: ceil(y)),
                          lines: lines,
                          images: images,
                          imageFrames: imageFrames,
                          metrics: metrics)
}

class ChatLineUiView: UIView {
    var onImageLoaded: (() -> Void)?
    private var content: ChatLineContent?
    private var layouts: [ChatLineLayout] = []
    private var currentLayout: ChatLineLayout?
    private var measuredWidth: CGFloat?
    private var imageViews: [EmoteUiView] = []

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(_ content: ChatLineContent) {
        guard content != self.content else {
            return
        }
        self.content = content
        layouts = []
        currentLayout = nil
        setNeedsLayout()
        setNeedsDisplay()
    }

    func size(availableWidth: CGFloat) -> CGSize {
        measuredWidth = availableWidth
        return layout(availableWidth: availableWidth)?.size ?? .zero
    }

    func unregister() {
        for imageView in imageViews {
            imageView.unregister()
        }
    }

    func link(at point: CGPoint) -> URL? {
        guard let content, let layout = currentLayout else {
            return nil
        }
        let x = point.x - content.leadingPadding
        for line in layout.lines {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(line.line, &ascent, &descent, nil)
            guard point.y >= line.baseline - ascent, point.y <= line.baseline + descent else {
                continue
            }
            for run in CTLineGetGlyphRuns(line.line) as! [CTRun] {
                let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                guard let link = attributes[linkKey] as? URL else {
                    continue
                }
                let start = CTLineGetOffsetForStringIndex(line.line, CTRunGetStringRange(run).location, nil)
                let width = CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
                if x >= start, x <= start + width {
                    return link
                }
            }
        }
        return nil
    }

    private func layout(availableWidth: CGFloat) -> ChatLineLayout? {
        guard let content else {
            return nil
        }
        if let layout = layouts.first(where: { $0.availableWidth == availableWidth }) {
            if !layout.hasUnknownImageSize || layout.sizesVersion == EmotesPlayer.shared.sizesVersion {
                return layout
            }
            layouts.removeAll(where: { $0.availableWidth == availableWidth })
        }
        let layout = makeLayout(content: content, availableWidth: availableWidth)
        layouts.append(layout)
        if layouts.count > 3 {
            layouts.removeFirst()
        }
        return layout
    }

    private func availableWidthForBounds() -> CGFloat {
        if let layout = layouts.first(where: { $0.size == bounds.size }) {
            return layout.availableWidth
        }
        return measuredWidth ?? bounds.width
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let content else {
            return
        }
        guard let layout = layout(availableWidth: availableWidthForBounds()) else {
            return
        }
        if currentLayout?.sizesVersion != layout.sizesVersion
            || currentLayout?.size != layout.size
            || currentLayout?.availableWidth != layout.availableWidth
        {
            setNeedsDisplay()
        }
        currentLayout = layout
        let images = layout.images
        while imageViews.count < images.count {
            let imageView = EmoteUiView()
            imageView.onLoaded = { [weak self] in
                self?.onImageLoaded?()
            }
            addSubview(imageView)
            imageViews.append(imageView)
        }
        while imageViews.count > images.count {
            let imageView = imageViews.removeLast()
            imageView.unregister()
            imageView.removeFromSuperview()
        }
        let borderWidth = content.borderColor != nil ? content.borderWidth : 0
        for (index, image) in images.enumerated() {
            let imageView = imageViews[index]
            imageView.frame = layout.imageFrames[index].insetBy(dx: -borderWidth, dy: -borderWidth)
            imageView.alpha = image.opacity
            imageView.setEmote(
                source: image.source,
                animated: image.animated,
                borderColor: content.borderColor,
                borderWidth: borderWidth
            )
        }
    }

    override func draw(_: CGRect) {
        guard let content, let layout = currentLayout, let context = UIGraphicsGetCurrentContext() else {
            return
        }
        if let backgroundColor = content.backgroundColor {
            context.setFillColor(backgroundColor.cgColor)
            context.addPath(UIBezierPath(roundedRect: bounds, cornerRadius: 5).cgPath)
            context.fillPath()
        }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        for line in layout.lines {
            guard let strokeLine = line.strokeLine else {
                continue
            }
            context.textPosition = CGPoint(x: content.leadingPadding, y: bounds.height - line.baseline)
            CTLineDraw(strokeLine, context)
        }
        for line in layout.lines {
            context.textPosition = CGPoint(x: content.leadingPadding, y: bounds.height - line.baseline)
            CTLineDraw(line.line, context)
        }
        context.restoreGState()
        drawStrikethroughs(content: content, layout: layout, context: context)
    }

    private func drawStrikethroughs(content: ChatLineContent, layout: ChatLineLayout, context: CGContext) {
        let thickness = max(content.fontSize / 16, 1)
        for line in layout.lines {
            for run in CTLineGetGlyphRuns(line.line) as! [CTRun] {
                let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
                guard attributes[strikethroughKey] as? Bool == true else {
                    continue
                }
                let x = CTLineGetOffsetForStringIndex(line.line, CTRunGetStringRange(run).location, nil)
                let width = CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil)
                let font = attributes[.font] as? UIFont
                let y = line.baseline - (font?.xHeight ?? content.fontSize / 2) / 2
                let color = attributes[.foregroundColor] as? UIColor ?? .white
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: content.leadingPadding + x,
                                    y: y - thickness / 2,
                                    width: width,
                                    height: thickness))
            }
        }
    }
}

struct ChatLineView: UIViewRepresentable {
    let content: ChatLineContent
    let onTap: ((URL?) -> Void)?
    @ObservedObject private var player = EmotesPlayer.shared

    init(content: ChatLineContent, onTap: ((URL?) -> Void)? = nil) {
        self.content = content
        self.onTap = onTap
    }

    @MainActor
    final class Coordinator {
        var onTap: ((URL?) -> Void)?

        init(onTap: ((URL?) -> Void)?) {
            self.onTap = onTap
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? ChatLineUiView else {
                return
            }
            onTap?(view.link(at: recognizer.location(in: view)))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    func makeUIView(context: Context) -> ChatLineUiView {
        let view = ChatLineUiView()
        updateTap(view, context: context)
        view.setContent(content)
        return view
    }

    func updateUIView(_ view: ChatLineUiView, context: Context) {
        updateTap(view, context: context)
        view.setContent(content)
    }

    private func updateTap(_ view: ChatLineUiView, context: Context) {
        context.coordinator.onTap = onTap
        view.isUserInteractionEnabled = onTap != nil
        if onTap != nil, view.gestureRecognizers?.isEmpty ?? true {
            view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                             action: #selector(Coordinator.handleTap)))
        }
    }

    static func dismantleUIView(_ view: ChatLineUiView, coordinator _: Coordinator) {
        view.unregister()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ChatLineUiView, context _: Context) -> CGSize? {
        uiView.setContent(content)
        var width = CGFloat.greatestFiniteMagnitude
        if let proposedWidth = proposal.width, proposedWidth > 0, proposedWidth.isFinite {
            width = proposedWidth
        }
        return uiView.size(availableWidth: width)
    }
}
