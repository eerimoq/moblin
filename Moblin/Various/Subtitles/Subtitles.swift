class Subtitles {
    private var lastLinePosition = 0
    private var previousFirstLinePosition = -1
    var lines: [String] = []
    private let length: Int

    init(languageIdentifier: String?) {
        if let languageIdentifier {
            if languageIdentifier.hasPrefix("zh") {
                length = 20
            } else if languageIdentifier == "ja" {
                length = 30
            } else {
                length = 50
            }
        } else {
            length = 50
        }
    }

    func updateSubtitles(position: Int, text: String) {
        guard position >= 0, !text.isEmpty else {
            return
        }
        let endPosition = position + text.count
        while lastLinePosition + length < endPosition {
            lastLinePosition += length
        }
        while lastLinePosition >= endPosition {
            lastLinePosition -= length
            lastLinePosition = max(lastLinePosition, 0)
        }
        let firstLinePosition = lastLinePosition - length
        let offset = lastLinePosition - position
        guard offset >= 0, offset < text.count else {
            return
        }
        let lastLineIndex = text.index(text.startIndex, offsetBy: offset)
        let lastLine = text[lastLineIndex...]
        if firstLinePosition >= position, firstLinePosition >= previousFirstLinePosition {
            previousFirstLinePosition = firstLinePosition
            let offset = firstLinePosition - position
            guard offset < text.count else {
                return
            }
            let firstLineIndex = text.index(text.startIndex, offsetBy: offset)
            let firstLine = text[firstLineIndex ..< lastLineIndex]
            lines = [firstLine.trim(), lastLine.trim()]
        } else {
            lines = [lastLine.trim()]
        }
    }
}
