import Collections
import FuzzyMatchingSwift

private let fuzzyMatchOptions = FuzzyMatchOptions(threshold: 0.34, distance: 1000)

private func fuzzyMatches(text: String, pattern: String) -> Bool {
    (text + " ").fuzzyMatchPattern(pattern, options: fuzzyMatchOptions) != nil
}

private func matchArgument<T: ChatBotArgument>(_ argument: String) -> T? {
    if let argument = T(rawValue: argument) {
        return argument
    }
    let matches = T.allCases.filter {
        fuzzyMatches(text: $0.rawValue, pattern: argument) && fuzzyMatches(
            text: argument,
            pattern: $0.rawValue
        )
    }
    guard matches.count == 1 else {
        return nil
    }
    return matches.first
}

protocol ChatBotArgument: RawRepresentable<String>, CaseIterable {}

enum ChatBotMainArgument: String, ChatBotArgument {
    case help
    case tts
    case obs
    case map
    case location
    case snapshot
    case mute
    case unmute
    case alert
    case fax
    case filter
    case zoom
    case say
    case tesla
    case reaction
    case scene
    case stream
    case widget
    case ai
    case twitch
    case gimbal
    case macro
    case send
    case music
    case custom
}

enum ChatBotOnOffArgument: String, ChatBotArgument {
    case on
    case off
}

enum ChatBotObsArgument: String, ChatBotArgument {
    case fix
}

enum ChatBotMapArgument: String, ChatBotArgument {
    case zoom
}

enum ChatBotMapZoomArgument: String, ChatBotArgument {
    case out
}

enum ChatBotLocationArgument: String, ChatBotArgument {
    case data
}

enum ChatBotLocationDataArgument: String, ChatBotArgument {
    case reset
    case split
}

enum ChatBotAiArgument: String, ChatBotArgument {
    case ask
}

enum ChatBotTwitchArgument: String, ChatBotArgument {
    case raid
}

enum ChatBotGimbalArgument: String, ChatBotArgument {
    case preset
}

enum ChatBotMacroArgument: String, ChatBotArgument {
    case run
    case cancel
}

enum ChatBotMusicArgument: String, ChatBotArgument {
    case play
    case pause
    case add
    case next
    case previous
    case status
}

enum ChatBotStreamArgument: String, ChatBotArgument {
    case start
    case stop
    case title
    case category
}

enum ChatBotWidgetArgument: String, ChatBotArgument {
    case enable
    case disable
    case timer
    case wheelOfLuck = "wheelofluck"
}

enum ChatBotWidgetTimerArgument: String, ChatBotArgument {
    case add
}

enum ChatBotWidgetWheelOfLuckArgument: String, ChatBotArgument {
    case spin
    case options
}

enum ChatBotFilterArgument: String, ChatBotArgument {
    case movie
    case grayscale
    case sepia
    case triple
    case twin
    case pixellate
    case fourThree = "4:3"
    case whirlpool
    case pinch
}

enum ChatBotTeslaArgument: String, ChatBotArgument {
    case trunk
    case media
}

enum ChatBotTeslaTrunkArgument: String, ChatBotArgument {
    case open
    case close
}

enum ChatBotTeslaMediaArgument: String, ChatBotArgument {
    case next
    case previous
    case togglePlayback = "toggle-playback"
}

struct ChatBotMessage {
    let platform: Platform
    let user: String?
    let isOwner: Bool
    let isModerator: Bool
    let isSubscriber: Bool
    let userId: String?
    let segments: [ChatPostSegment]
}

class ChatBotCommand {
    let message: ChatBotMessage
    private var parts: Deque<String> = []

    init?(message: ChatBotMessage, aliases: [SettingsChatBotAlias]) {
        self.message = message
        guard let firstWord = message.segments.first?.text?.lowercased().trim() else {
            return nil
        }
        if firstWord != "!moblin" {
            guard let alias = aliases.first(where: { $0.alias == firstWord }) else {
                return nil
            }
            for word in alias.replacement.split(separator: " ").suffix(from: 1) {
                parts.append(word.trim())
            }
        }
        if message.segments.count > 1 {
            for segment in message.segments.suffix(from: 1) {
                if let text = segment.text {
                    parts.append(text.trim())
                }
            }
        }
    }

    func popFirst() -> String? {
        guard var first = parts.popFirst() else {
            return nil
        }
        guard first.starts(with: "\"") else {
            return first
        }
        first.removeFirst()
        guard first != "\"" else {
            return ""
        }
        var words = [first]
        while var word = parts.popFirst() {
            if word.hasSuffix("\"") {
                word.removeLast()
                words.append(word)
                return words.joined(separator: " ")
            } else {
                words.append(word)
            }
        }
        return nil
    }

    func popFirstLowerCased() -> String? {
        popFirst()?.lowercased()
    }

    func popFirstArgument<T: ChatBotArgument>(_: T.Type) -> T? {
        guard let word = popFirstLowerCased() else {
            return nil
        }
        return matchArgument(word)
    }

    func popAll() -> [String] {
        var parts: [String] = []
        while let part = popFirst() {
            parts.append(part)
        }
        return parts
    }

    func peekFirst() -> String? {
        parts.first
    }

    func rest() -> String {
        parts.joined(separator: " ")
    }

    func user() -> String? {
        message.user
    }
}
