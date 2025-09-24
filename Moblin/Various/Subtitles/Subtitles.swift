class Subtitles {
    private var lastLinePosition = 0
    private var previousFirstLinePosition = -1
    var lines: [String] = []

    func updateSubtitles(position: Int, text: String) {
        let endPosition = position + text.count
        let length = 50
        while lastLinePosition + length < endPosition {
            lastLinePosition += length
        }
        while lastLinePosition >= endPosition {
            lastLinePosition -= length
            lastLinePosition = max(lastLinePosition, 0)
        }
        let firstLinePosition = lastLinePosition - length
        let lastLineIndex = text.index(text.startIndex, offsetBy: lastLinePosition - position)
        let lastLine = text[lastLineIndex...]
        if firstLinePosition >= position, firstLinePosition >= previousFirstLinePosition {
            previousFirstLinePosition = firstLinePosition
            let firstLineIndex = text.index(text.startIndex, offsetBy: firstLinePosition - position)
            let firstLine = text[firstLineIndex ..< lastLineIndex]
            lines = [firstLine.trim(), lastLine.trim()]
        } else {
            lines = [lastLine.trim()]
        }
    }
}
