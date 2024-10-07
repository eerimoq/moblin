import Foundation

enum TextFormatPart {
    case text(String)
    case newLine
    case clock
    case date
    case fullDate
    case bitrateAndTotal
    case debugOverlay
    case speed
    case altitude
    case distance
    case timer
    case conditions
    case temperature
    case country
    case countryFlag
    case city
    case checkbox
    case rating
    case subtitles
    case muted
    case heartRate
    case activeEnergyBurned
    case power
    case stepCount
    case workoutDistance
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
                    loadItem(part: .clock, offsetBy: 6)
                } else if formatFromIndex.hasPrefix("{date}") {
                    loadItem(part: .date, offsetBy: 6)
                } else if formatFromIndex.hasPrefix("{fulldate}") {
                    loadItem(part: .fullDate, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{bitrateandtotal}") {
                    loadItem(part: .bitrateAndTotal, offsetBy: 17)
                } else if formatFromIndex.hasPrefix("{debugoverlay}") {
                    loadItem(part: .debugOverlay, offsetBy: 14)
                } else if formatFromIndex.hasPrefix("{speed}") {
                    loadItem(part: .speed, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{altitude}") {
                    loadItem(part: .altitude, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{distance}") {
                    loadItem(part: .distance, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{timer}") {
                    loadItem(part: .timer, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{conditions}") {
                    loadItem(part: .conditions, offsetBy: 12)
                } else if formatFromIndex.hasPrefix("{temperature}") {
                    loadItem(part: .temperature, offsetBy: 13)
                } else if formatFromIndex.hasPrefix("{country}") {
                    loadItem(part: .country, offsetBy: 9)
                } else if formatFromIndex.hasPrefix("{countryflag}") {
                    loadItem(part: .countryFlag, offsetBy: 13)
                } else if formatFromIndex.hasPrefix("{city}") {
                    loadItem(part: .city, offsetBy: 6)
                } else if formatFromIndex.hasPrefix("{checkbox}") {
                    loadItem(part: .checkbox, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{rating}") {
                    loadItem(part: .rating, offsetBy: 8)
                } else if formatFromIndex.hasPrefix("{subtitles}") {
                    loadItem(part: .subtitles, offsetBy: 11)
                } else if formatFromIndex.hasPrefix("{muted}") {
                    loadItem(part: .muted, offsetBy: 7)
                } else if isPhone(), formatFromIndex.hasPrefix("{heartrate}") {
                    loadItem(part: .heartRate, offsetBy: 11)
                } else if isPhone(), formatFromIndex.hasPrefix("{activeenergyburned}") {
                    loadItem(part: .activeEnergyBurned, offsetBy: 20)
                } else if isPhone(), formatFromIndex.hasPrefix("{power}") {
                    loadItem(part: .power, offsetBy: 7)
                } else if isPhone(), formatFromIndex.hasPrefix("{stepcount}") {
                    loadItem(part: .stepCount, offsetBy: 11)
                } else if isPhone(), formatFromIndex.hasPrefix("{workoutdistance}") {
                    loadItem(part: .workoutDistance, offsetBy: 17)
                } else {
                    index = format.index(after: index)
                }
            case "\n":
                loadItem(part: .newLine, offsetBy: 1)
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

    private func loadItem(part: TextFormatPart, offsetBy: Int) {
        appendTextIfPresent()
        parts.append(part)
        index = format.index(index, offsetBy: offsetBy)
        textStartIndex = index
    }
}

func loadTextFormat(format: String) -> [TextFormatPart] {
    return TextFormatLoader().load(format: format)
}

extension [TextFormatPart] {
    func getCheckboxText(index: Int) -> String {
        var afterCheckbox = false
        var checkboxTexts: [String] = []
        var currentIndex = 0
        for part in self {
            switch part {
            case let .text(text):
                if afterCheckbox {
                    checkboxTexts.append(text)
                    afterCheckbox = false
                }
            case .newLine:
                if afterCheckbox {
                    checkboxTexts.append("Checkbox \(currentIndex)")
                }
                afterCheckbox = false
            case .checkbox:
                if afterCheckbox {
                    checkboxTexts.append("Checkbox \(currentIndex)")
                }
                afterCheckbox = true
                currentIndex += 1
            default:
                break
            }
        }
        guard index < checkboxTexts.count else {
            return ""
        }
        return checkboxTexts[index]
    }
}
