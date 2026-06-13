import Foundation

enum TextFormatPart: Equatable {
    case text(String)
    case newLine
    case clock
    case shortClock
    case date
    case fullDate
    case bitrate
    case bitrateAndTotal
    case resolution
    case fps
    case debugOverlay
    case speed(String?)
    case averageSpeed(String?)
    case altitude(String?)
    case distance(String?)
    case splitDistance(String?)
    case slope
    case timer
    case stopwatch
    case conditions
    case temperature(String?)
    case feelsLikeTemperature(String?)
    case wind(String?)
    case windKmh
    case country
    case countryFlag
    case state
    case city
    case checkbox
    case rating
    case subtitles(String?)
    case muted
    case heartRate(String)
    case activeEnergyBurned
    case power
    case stepCount
    case workoutDistance(String?)
    case teslaBatteryLevel
    case teslaDrive
    case teslaMedia
    case cyclingPower
    case cyclingCadence
    case runningPace(String, String?)
    case runningCadence(String)
    case runningDistance(String, String?)
    case lapTimes
    case browserTitle
    case gForce(String?)
    case gForceRecentMax(String?)
    case gForceMax(String?)
    case latestSubscriber
    case latestFollower
}

@MainActor
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
                } else if formatFromIndex.hasPrefix("{shorttime}") {
                    loadItem(part: .shortClock, offsetBy: 11)
                } else if formatFromIndex.hasPrefix("{date}") {
                    loadItem(part: .date, offsetBy: 6)
                } else if formatFromIndex.hasPrefix("{fulldate}") {
                    loadItem(part: .fullDate, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{bitrate}") {
                    loadItem(part: .bitrate, offsetBy: 9)
                } else if formatFromIndex.hasPrefix("{bitrateandtotal}") {
                    loadItem(part: .bitrateAndTotal, offsetBy: 17)
                } else if formatFromIndex.hasPrefix("{resolution}") {
                    loadItem(part: .resolution, offsetBy: 12)
                } else if formatFromIndex.hasPrefix("{fps}") {
                    loadItem(part: .fps, offsetBy: 5)
                } else if formatFromIndex.hasPrefix("{debugoverlay}") {
                    loadItem(part: .debugOverlay, offsetBy: 14)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "speed") {
                    loadItem(part: .speed(match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "averagespeed") {
                    loadItem(part: .averageSpeed(match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "altitude") {
                    loadItem(part: .altitude(match.unit), offsetBy: match.offset)
                } else if let match = parseRunningMetric(formatFromIndex: formatFromIndex, name: "runningdistance", validUnits: ["m", "km", "mi", "yd", "ft"]) {
                    loadItem(part: .runningDistance(match.device, match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "splitdistance") {
                    loadItem(part: .splitDistance(match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "distance") {
                    loadItem(part: .distance(match.unit), offsetBy: match.offset)
                } else if formatFromIndex.hasPrefix("{slope}") {
                    loadItem(part: .slope, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{timer}") {
                    loadItem(part: .timer, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{stopwatch}") {
                    loadItem(part: .stopwatch, offsetBy: 11)
                } else if formatFromIndex.hasPrefix("{conditions}") {
                    loadItem(part: .conditions, offsetBy: 12)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "temperature") {
                    loadItem(part: .temperature(match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "feelsliketemperature") {
                    loadItem(part: .feelsLikeTemperature(match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "wind") {
                    loadItem(part: .wind(match.unit), offsetBy: match.offset)
                } else if formatFromIndex.hasPrefix("{windkmh}") {
                    loadItem(part: .windKmh, offsetBy: 9)
                } else if formatFromIndex.hasPrefix("{country}") {
                    loadItem(part: .country, offsetBy: 9)
                } else if formatFromIndex.hasPrefix("{countryflag}") {
                    loadItem(part: .countryFlag, offsetBy: 13)
                } else if formatFromIndex.hasPrefix("{state}") {
                    loadItem(part: .state, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{city}") {
                    loadItem(part: .city, offsetBy: 6)
                } else if formatFromIndex.hasPrefix("{checkbox}") {
                    loadItem(part: .checkbox, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{rating}") {
                    loadItem(part: .rating, offsetBy: 8)
                } else if formatFromIndex.hasPrefix("{muted}") {
                    loadItem(part: .muted, offsetBy: 7)
                } else if appendHeartRateIfPresent(formatFromIndex: formatFromIndex) {
                } else if appendSubtitlesIfPresent(formatFromIndex: formatFromIndex) {
                } else if let match = parseRunningMetric(formatFromIndex: formatFromIndex, name: "runningpace", validUnits: ["min/km", "min/mile"]) {
                    loadItem(part: .runningPace(match.device, match.unit), offsetBy: match.offset)
                } else if appendCadenceIfPresent(formatFromIndex: formatFromIndex) {
                } else if !isMac(), formatFromIndex.hasPrefix("{activeenergyburned}") {
                    loadItem(part: .activeEnergyBurned, offsetBy: 20)
                } else if !isMac(), formatFromIndex.hasPrefix("{power}") {
                    loadItem(part: .power, offsetBy: 7)
                } else if !isMac(), formatFromIndex.hasPrefix("{stepcount}") {
                    loadItem(part: .stepCount, offsetBy: 11)
                } else if !isMac(), let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "workoutdistance") {
                    loadItem(part: .workoutDistance(match.unit), offsetBy: match.offset)
                } else if formatFromIndex.hasPrefix("{teslabatterylevel}") {
                    loadItem(part: .teslaBatteryLevel, offsetBy: 19)
                } else if formatFromIndex.hasPrefix("{tesladrive}") {
                    loadItem(part: .teslaDrive, offsetBy: 12)
                } else if formatFromIndex.hasPrefix("{teslamedia}") {
                    loadItem(part: .teslaMedia, offsetBy: 12)
                } else if formatFromIndex.hasPrefix("{cyclingpower}") {
                    loadItem(part: .cyclingPower, offsetBy: 14)
                } else if formatFromIndex.hasPrefix("{cyclingcadence}") {
                    loadItem(part: .cyclingCadence, offsetBy: 16)
                } else if formatFromIndex.hasPrefix("{laptimes}") {
                    loadItem(part: .lapTimes, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{browsertitle}") {
                    loadItem(part: .browserTitle, offsetBy: 14)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "gforce") {
                    loadItem(part: .gForce(match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "gforcerecentmax") {
                    loadItem(part: .gForceRecentMax(match.unit), offsetBy: match.offset)
                } else if let match = parseVariableWithUnit(formatFromIndex: formatFromIndex, name: "gforcemax") {
                    loadItem(part: .gForceMax(match.unit), offsetBy: match.offset)
                } else if formatFromIndex.hasPrefix("{latestsubscriber}") {
                    loadItem(part: .latestSubscriber, offsetBy: 18)
                } else if formatFromIndex.hasPrefix("{latestfollower}") {
                    loadItem(part: .latestFollower, offsetBy: 16)
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

    private func parseVariableWithUnit(formatFromIndex: String, name: String) -> (unit: String?, offset: Int)? {
        let prefix = "{\(name)}"
        if formatFromIndex.hasPrefix(prefix) {
            return (nil, prefix.count)
        }
        let prefixWithColon = "{\(name):"
        if formatFromIndex.hasPrefix(prefixWithColon) {
            if let closeBraceIndex = formatFromIndex.firstIndex(of: "}") {
                let startOfUnit = formatFromIndex.index(formatFromIndex.startIndex, offsetBy: prefixWithColon.count)
                if startOfUnit < closeBraceIndex {
                    let unit = String(formatFromIndex[startOfUnit ..< closeBraceIndex])
                    let offset = formatFromIndex.distance(from: formatFromIndex.startIndex, to: closeBraceIndex) + 1
                    return (unit, offset)
                }
            }
        }
        return nil
    }

    private func parseRunningMetric(formatFromIndex: String, name: String, validUnits: [String]) -> (device: String, unit: String?, offset: Int)? {
        let prefix = "{\(name)}"
        if formatFromIndex.hasPrefix(prefix) {
            return ("", nil, prefix.count)
        }
        let prefixWithColon = "{\(name):"
        if formatFromIndex.hasPrefix(prefixWithColon) {
            if let closeBraceIndex = formatFromIndex.firstIndex(of: "}") {
                let startOfContent = formatFromIndex.index(formatFromIndex.startIndex, offsetBy: prefixWithColon.count)
                if startOfContent < closeBraceIndex {
                    let content = String(formatFromIndex[startOfContent ..< closeBraceIndex])
                    let offset = formatFromIndex.distance(from: formatFromIndex.startIndex, to: closeBraceIndex) + 1
                    let parts = content.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
                    if parts.count == 2 {
                        return (parts[0], parts[1], offset)
                    } else if parts.count == 1 {
                        let singlePart = parts[0]
                        if validUnits.contains(singlePart.lowercased()) {
                            return ("", singlePart, offset)
                        } else {
                            return (singlePart, nil, offset)
                        }
                    }
                }
            }
        }
        return nil
    }

    private func appendHeartRateIfPresent(formatFromIndex: String) -> Bool {
        if formatFromIndex.hasPrefix("{heartrate}") {
            loadItem(part: .heartRate(""), offsetBy: 11)
            return true
        } else if let match = formatFromIndex.prefixMatch(of: /{heartrate:([^}]+)}/) {
            let deviceName = String(match.output.1)
            loadItem(part: .heartRate(deviceName), offsetBy: match.output.0.count)
            return true
        } else {
            return false
        }
    }

    private func appendCadenceIfPresent(formatFromIndex: String) -> Bool {
        if formatFromIndex.hasPrefix("{runningcadence}") {
            loadItem(part: .runningCadence(""), offsetBy: 16)
            return true
        } else if let match = formatFromIndex.prefixMatch(of: /{runningcadence:([^}]+)}/) {
            let deviceName = String(match.output.1)
            loadItem(part: .runningCadence(deviceName), offsetBy: match.output.0.count)
            return true
        } else {
            return false
        }
    }

    private func appendSubtitlesIfPresent(formatFromIndex: String) -> Bool {
        if formatFromIndex.hasPrefix("{subtitles}") {
            loadItem(part: .subtitles(nil), offsetBy: 11)
            return true
        } else if let match = formatFromIndex.prefixMatch(of: /{subtitles:([^}]+)}/) {
            let languageIdentifier = String(match.output.1)
            loadItem(part: .subtitles(languageIdentifier), offsetBy: match.output.0.count)
            return true
        } else {
            return false
        }
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

@MainActor
func loadTextFormat(format: String) -> [TextFormatPart] {
    TextFormatLoader().load(format: format)
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

    func isWorkoutVariable() -> Bool {
        for part in self {
            switch part {
            case .heartRate, .activeEnergyBurned, .power, .stepCount, .workoutDistance:
                return true
            default:
                break
            }
        }
        return false
    }

    func isWeatherVariable() -> Bool {
        for part in self {
            switch part {
            case .conditions, .temperature, .feelsLikeTemperature, .wind, .windKmh:
                return true
            default:
                break
            }
        }
        return false
    }

    func isLocationVariable() -> Bool {
        for part in self {
            switch part {
            case .speed, .averageSpeed, .altitude, .distance, .slope, .country, .countryFlag, .state, .city:
                return true
            default:
                break
            }
        }
        return false
    }
}
