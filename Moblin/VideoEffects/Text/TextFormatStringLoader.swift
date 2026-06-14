import Foundation

enum TextFormatSpeedUnit {
    case system
    case metersPerSecond
    case kilometersPerHour
    case milesPerHour

    init?(_ value: String) {
        switch value {
        case "m/s":
            self = .metersPerSecond
        case "km/h":
            self = .kilometersPerHour
        case "mph":
            self = .milesPerHour
        default:
            return nil
        }
    }

    func toSystem() -> UnitSpeed? {
        switch self {
        case .system:
            nil
        case .metersPerSecond:
            .metersPerSecond
        case .kilometersPerHour:
            .kilometersPerHour
        case .milesPerHour:
            .milesPerHour
        }
    }
}

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
    case speed(TextFormatSpeedUnit)
    case averageSpeed(TextFormatSpeedUnit)
    case altitude(String?)
    case distance(String?)
    case splitDistance(String?)
    case slope
    case timer
    case stopwatch
    case conditions
    case temperature(String?)
    case feelsLikeTemperature(String?)
    case wind(TextFormatSpeedUnit)
    case country
    case countryFlag
    case state
    case city
    case region
    case area
    case suburb
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
                } else if appendSpeedIfPresent(formatFromIndex: formatFromIndex) {
                } else if appendAverageSpeedIfPresent(formatFromIndex: formatFromIndex) {
                } else if formatFromIndex.hasPrefix("{altitude}") {
                    loadItem(part: .altitude(nil), offsetBy: 10)
                } else if appendRunDistanceIfPresent(formatFromIndex: formatFromIndex) {
                } else if formatFromIndex.hasPrefix("{splitdistance}") {
                    loadItem(part: .splitDistance(nil), offsetBy: 15)
                } else if formatFromIndex.hasPrefix("{distance}") {
                    loadItem(part: .distance(nil), offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{slope}") {
                    loadItem(part: .slope, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{timer}") {
                    loadItem(part: .timer, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{stopwatch}") {
                    loadItem(part: .stopwatch, offsetBy: 11)
                } else if formatFromIndex.hasPrefix("{conditions}") {
                    loadItem(part: .conditions, offsetBy: 12)
                } else if formatFromIndex.hasPrefix("{temperature}") {
                    loadItem(part: .temperature(nil), offsetBy: 13)
                } else if formatFromIndex.hasPrefix("{feelsliketemperature}") {
                    loadItem(part: .feelsLikeTemperature(nil), offsetBy: 22)
                } else if appendWindIfPresent(formatFromIndex: formatFromIndex) {
                } else if formatFromIndex.hasPrefix("{country}") {
                    loadItem(part: .country, offsetBy: 9)
                } else if formatFromIndex.hasPrefix("{countryflag}") {
                    loadItem(part: .countryFlag, offsetBy: 13)
                } else if formatFromIndex.hasPrefix("{state}") {
                    loadItem(part: .state, offsetBy: 7)
                } else if formatFromIndex.hasPrefix("{city}") {
                    loadItem(part: .city, offsetBy: 6)
                } else if formatFromIndex.hasPrefix("{region}") {
                    loadItem(part: .region, offsetBy: 8)
                } else if formatFromIndex.hasPrefix("{area}") {
                    loadItem(part: .area, offsetBy: 6)
                } else if formatFromIndex.hasPrefix("{suburb}") {
                    loadItem(part: .suburb, offsetBy: 8)
                } else if formatFromIndex.hasPrefix("{checkbox}") {
                    loadItem(part: .checkbox, offsetBy: 10)
                } else if formatFromIndex.hasPrefix("{rating}") {
                    loadItem(part: .rating, offsetBy: 8)
                } else if formatFromIndex.hasPrefix("{muted}") {
                    loadItem(part: .muted, offsetBy: 7)
                } else if appendHeartRateIfPresent(formatFromIndex: formatFromIndex) {
                } else if appendSubtitlesIfPresent(formatFromIndex: formatFromIndex) {
                } else if appendPaceIfPresent(formatFromIndex: formatFromIndex) {
                } else if appendCadenceIfPresent(formatFromIndex: formatFromIndex) {
                } else if !isMac(), formatFromIndex.hasPrefix("{activeenergyburned}") {
                    loadItem(part: .activeEnergyBurned, offsetBy: 20)
                } else if !isMac(), formatFromIndex.hasPrefix("{power}") {
                    loadItem(part: .power, offsetBy: 7)
                } else if !isMac(), formatFromIndex.hasPrefix("{stepcount}") {
                    loadItem(part: .stepCount, offsetBy: 11)
                } else if !isMac(), formatFromIndex.hasPrefix("{workoutdistance}") {
                    loadItem(part: .workoutDistance(nil), offsetBy: 17)
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
                } else if formatFromIndex.hasPrefix("{gforce}") {
                    loadItem(part: .gForce(nil), offsetBy: 8)
                } else if formatFromIndex.hasPrefix("{gforcerecentmax}") {
                    loadItem(part: .gForceRecentMax(nil), offsetBy: 17)
                } else if formatFromIndex.hasPrefix("{gforcemax}") {
                    loadItem(part: .gForceMax(nil), offsetBy: 11)
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

    private func appendSpeedIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{speed}",
                               /{speed:([^}]+)}/,
                               TextFormatSpeedUnit.init) { .speed($0 ?? .system) }
    }

    private func appendAverageSpeedIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{averagespeed}",
                               /{averagespeed:([^}]+)}/,
                               TextFormatSpeedUnit.init) { .averageSpeed($0 ?? .system) }
    }

    private func appendHeartRateIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{heartrate}",
                               /{heartrate:([^}]+)}/,
                               { $0 },
                               { .heartRate($0 ?? "") })
    }

    private func appendPaceIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{runningpace}",
                               /{runningpace:([^}]+)}/,
                               { $0 },
                               { .runningPace($0 ?? "", nil) })
    }

    private func appendCadenceIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{runningcadence}",
                               /{runningcadence:([^}]+)}/,
                               { $0 },
                               { .runningCadence($0 ?? "") })
    }

    private func appendRunDistanceIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{runningdistance}",
                               /{runningdistance:([^}]+)}/,
                               { $0 },
                               { .runningDistance($0 ?? "", nil) })
    }

    private func appendWindIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{wind}",
                               /{wind:([^}]+)}/,
                               TextFormatSpeedUnit.init) { .wind($0 ?? .system) }
    }

    private func appendSubtitlesIfPresent(formatFromIndex: String) -> Bool {
        appendOptionsIfPresent(formatFromIndex,
                               "{subtitles}",
                               /{subtitles:([^}]+)}/,
                               { $0 },
                               { .subtitles($0) })
    }

    private func appendOptionsIfPresent<Options>(_ formatFromIndex: String,
                                                 _ plain: String,
                                                 _ regex: Regex<(Substring, Substring)>,
                                                 _ makeOptions: (String) -> Options?,
                                                 _ makePart: (Options?) -> TextFormatPart) -> Bool
    {
        if formatFromIndex.hasPrefix(plain) {
            loadItem(part: makePart(nil), offsetBy: plain.count)
            return true
        } else if let match = formatFromIndex.prefixMatch(of: regex),
                  let options = makeOptions(String(match.output.1))
        {
            loadItem(part: makePart(options), offsetBy: match.output.0.count)
            return true
        }
        return false
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
        for variable in self {
            switch variable {
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
        for variable in self {
            switch variable {
            case .heartRate:
                return true
            case .activeEnergyBurned:
                return true
            case .power:
                return true
            case .stepCount:
                return true
            case .workoutDistance:
                return true
            default:
                break
            }
        }
        return false
    }

    func isWeatherVariable() -> Bool {
        for variable in self {
            switch variable {
            case .conditions:
                return true
            case .temperature:
                return true
            case .feelsLikeTemperature:
                return true
            case .wind:
                return true
            default:
                break
            }
        }
        return false
    }

    func isLocationVariable() -> Bool {
        for variable in self {
            switch variable {
            case .speed:
                return true
            case .averageSpeed:
                return true
            case .altitude:
                return true
            case .distance:
                return true
            case .slope:
                return true
            case .country:
                return true
            case .countryFlag:
                return true
            case .state:
                return true
            case .city:
                return true
            case .region:
                return true
            case .area:
                return true
            case .suburb:
                return true
            default:
                break
            }
        }
        return false
    }
}
