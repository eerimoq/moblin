import SwiftUI

/// A UIViewRepresentable wrapper around UITextView that detects links and makes them tappable.
/// It supports basic attributed styling: font, color, italic, strikethrough.
struct DetectingTextView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let italic: Bool
    let strikethrough: Bool

    init(_ text: String,
         font: UIFont = UIFont.systemFont(ofSize: UIFont.systemFontSize),
         textColor: UIColor = UIColor.white,
         italic: Bool = false,
         strikethrough: Bool = false) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.italic = italic
        self.strikethrough = strikethrough
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.dataDetectorTypes = [] // We'll add links ourselves via attributed string
        tv.adjustsFontForContentSizeCategory = true
        tv.linkTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.systemBlue]
        tv.isUserInteractionEnabled = true
        tv.isAccessibilityElement = true
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let attributed = makeAttributedString()
        uiView.attributedText = attributed
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    private func makeAttributedString() -> NSAttributedString {
        // Build base attributes
        var baseFont = font
        if italic, let it = italicVariant(of: font) {
            baseFont = it
        }
        var attributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor
        ]
        if strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }

        let attr = NSMutableAttributedString(string: text, attributes: attributes)

        // Detect links using NSDataDetector and add NSLinkAttributeName
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            detector.enumerateMatches(in: text, options: [], range: range) { (match, _, _) in
                guard let match = match, let url = match.url else { return }
                attr.addAttribute(.link, value: url.absoluteString, range: match.range)
            }
        }

        return attr
    }

    private func italicVariant(of font: UIFont) -> UIFont? {
        var traits = font.fontDescriptor.symbolicTraits
        traits.insert(.traitItalic)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        return nil
    }

    class Coordinator: NSObject, UITextViewDelegate {
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            // Use the project's helper to open URLs so behaviour is consistent
            DispatchQueue.main.async {
                openUrl(url: URL.absoluteString)
            }
            return false
        }

        // Support older variant without interaction param
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            DispatchQueue.main.async {
                openUrl(url: URL.absoluteString)
            }
            return false
        }
    }
}
