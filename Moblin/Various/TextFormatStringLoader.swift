import Foundation

enum TextFormatPart {
    case text(String)
    case clock
    case bitrateAndTotal
    case debugOverlay
    case speed
    case altitude
    case distance
    case timer
    case conditions
    case temperature
}

class TextFormatLoader {
    private var format: String = ""
    private var parts: [TextFormatPart] = []
    private var index: String.Index!
    private var textStartIndex: String.Index!

    func load(format inputFormat: String) -> [TextFormatPart] {
        format = inputFormat.replacing("\\n", with: "\n")
        parts = []
        index = format.startIndex
        textStartIndex = format.startIndex
        while index < format.endIndex {
            switch format[index] {
            case "{":
                let formatFromIndex = format[index ..< format.endIndex].lowercased()
                if formatFromIndex.hasPrefix("{time}") {
                    loadTime()
                } else if formatFromIndex.hasPrefix("{bitrateandtotal}") {
                    loadBitrateAndTotal()
                } else if formatFromIndex.hasPrefix("{debugoverlay}") {
                    loadDebugOverlay()
                } else if formatFromIndex.hasPrefix("{speed}") {
                    loadSpeed()
                } else if formatFromIndex.hasPrefix("{altitude}") {
                    loadAltitude()
                } else if formatFromIndex.hasPrefix("{distance}") {
                    loadDistance()
                } else if formatFromIndex.hasPrefix("{timer}") {
                    loadTimer()
                } else if formatFromIndex.hasPrefix("{conditions}") {
                    loadConditions()
                } else if formatFromIndex.hasPrefix("{temperature}") {
                    loadTemperature()
                } else {
                    index = format.index(after: index)
                }
            default:
                index = format.index(after: index)
            }
        }
        appendTextIfPresent()
        return parts
    }

    private func appendTextIfPresent() {
        if textStartIndex < index {
            parts.append(.text(String(format[textStartIndex ..< index])))
        }
    }

    private func loadTime() {
        appendTextIfPresent()
        parts.append(.clock)
        index = format.index(index, offsetBy: 6)
        textStartIndex = index
    }

    private func loadBitrateAndTotal() {
        appendTextIfPresent()
        parts.append(.bitrateAndTotal)
        index = format.index(index, offsetBy: 17)
        textStartIndex = index
    }

    private func loadDebugOverlay() {
        appendTextIfPresent()
        parts.append(.debugOverlay)
        index = format.index(index, offsetBy: 14)
        textStartIndex = index
    }

    private func loadSpeed() {
        appendTextIfPresent()
        parts.append(.speed)
        index = format.index(index, offsetBy: 7)
        textStartIndex = index
    }

    private func loadAltitude() {
        appendTextIfPresent()
        parts.append(.altitude)
        index = format.index(index, offsetBy: 10)
        textStartIndex = index
    }

    private func loadDistance() {
        appendTextIfPresent()
        parts.append(.distance)
        index = format.index(index, offsetBy: 10)
        textStartIndex = index
    }

    private func loadTimer() {
        appendTextIfPresent()
        parts.append(.timer)
        index = format.index(index, offsetBy: 7)
        textStartIndex = index
    }

    private func loadConditions() {
        appendTextIfPresent()
        parts.append(.conditions)
        index = format.index(index, offsetBy: 12)
        textStartIndex = index
    }

    private func loadTemperature() {
        appendTextIfPresent()
        parts.append(.temperature)
        index = format.index(index, offsetBy: 13)
        textStartIndex = index
    }
}

func loadTextFormat(format: String) -> [TextFormatPart] {
    return TextFormatLoader().load(format: format)
}
