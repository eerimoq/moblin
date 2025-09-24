class TextAligner {
    private var text: String
    var position: Int

    init(text: String) {
        self.text = text
        position = 0
    }

    func update(text newText: String) {
        let oldText = text
        if newText == oldText {
            return
        }
        let newLength = newText.count
        let oldLength = oldText.count
        if oldLength == 0 || newLength == 0 {
            text = newText
            return
        }
        let shiftLimit = 25
        let minShift = max(-(newLength - 1), -shiftLimit)
        let maxShift = min(oldLength - 1, shiftLimit)
        var bestShift = 0
        var bestMatches = -1
        for shift in minShift ... maxShift {
            let startOffset = max(0, -shift)
            let endOffset = min(newLength - 1, (oldLength - 1) - shift)
            if startOffset > endOffset {
                continue
            }
            var matches = 0
            var offset = startOffset
            while offset <= endOffset {
                let newIndex = newText.index(newText.startIndex, offsetBy: offset)
                let oldIndex = oldText.index(oldText.startIndex, offsetBy: offset + shift)
                if newText[newIndex] == oldText[oldIndex] {
                    matches += 1
                }
                offset += 1
            }
            if matches > bestMatches
                || (matches == bestMatches && abs(shift) < abs(bestShift))
                || (matches == bestMatches && abs(shift) == abs(bestShift) && shift == 0)
            {
                bestMatches = matches
                bestShift = shift
            }
        }
        position += bestShift
        text = newText
    }
}
