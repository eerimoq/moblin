import Foundation
import SwiftUI

class SettingsChatFilter: Identifiable, Codable, ObservableObject {
    var id = UUID()
    @Published var user: String = ""
    @Published var messageStart: String = ""
    var messageStartWords: [String] = []
    @Published var showOnScreen: Bool = false
    @Published var textToSpeech: Bool = false
    @Published var chatBot: Bool = false
    @Published var poll: Bool = false
    @Published var print: Bool = false

    func isMatching(user: String?, segments: [ChatPostSegment]) -> Bool {
        if self.user.count > 0, user != self.user {
            return false
        }
        var segmentsIterator = segments.makeIterator()
        for messageWord in messageStartWords {
            if let text = firstText(segmentsIterator: &segmentsIterator) {
                if !text.starts(with: messageWord) {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }

    func username() -> String {
        if user.isEmpty {
            return String(localized: "-- Any --")
        } else {
            return user
        }
    }

    func message() -> String {
        if messageStart.isEmpty {
            return String(localized: "-- Any --")
        } else {
            return messageStart
        }
    }

    private func firstText(segmentsIterator: inout IndexingIterator<[ChatPostSegment]>) -> String? {
        while let segment = segmentsIterator.next() {
            if let text = segment.text, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    enum CodingKeys: CodingKey {
        case id,
             value,
             messageWords,
             showOnScreen,
             textToSpeech,
             chatBot,
             poll,
             print
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.value, user)
        try container.encode(.messageWords, messageStartWords)
        try container.encode(.showOnScreen, showOnScreen)
        try container.encode(.textToSpeech, textToSpeech)
        try container.encode(.chatBot, chatBot)
        try container.encode(.poll, poll)
        try container.encode(.print, print)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        user = container.decode(.value, String.self, "")
        messageStartWords = container.decode(.messageWords, [String].self, [])
        messageStart = messageStartWords.joined(separator: " ")
        showOnScreen = container.decode(.showOnScreen, Bool.self, false)
        textToSpeech = container.decode(.textToSpeech, Bool.self, false)
        chatBot = container.decode(.chatBot, Bool.self, false)
        poll = container.decode(.poll, Bool.self, false)
        print = container.decode(.print, Bool.self, false)
    }
}

class SettingsChatBotPermissionsCommand: Codable, ObservableObject {
    @Published var moderatorsEnabled: Bool = true
    @Published var subscribersEnabled: Bool = false
    @Published var minimumSubscriberTier: Int = 1
    @Published var othersEnabled: Bool = false
    @Published var sendChatMessages: Bool = false
    @Published var cooldown: Int?
    var latestExecutionTime: ContinuousClock.Instant?

    enum CodingKeys: CodingKey {
        case moderatorsEnabled,
             subscribersEnabled,
             minimumSubscriberTier,
             othersEnabled,
             sendChatMessages,
             cooldown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.moderatorsEnabled, moderatorsEnabled)
        try container.encode(.subscribersEnabled, subscribersEnabled)
        try container.encode(.minimumSubscriberTier, minimumSubscriberTier)
        try container.encode(.othersEnabled, othersEnabled)
        try container.encode(.sendChatMessages, sendChatMessages)
        try container.encode(.cooldown, cooldown)
    }

    init(moderatorsEnabled: Bool = true) {
        self.moderatorsEnabled = moderatorsEnabled
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        moderatorsEnabled = container.decode(.moderatorsEnabled, Bool.self, true)
        subscribersEnabled = container.decode(.subscribersEnabled, Bool.self, false)
        minimumSubscriberTier = container.decode(.minimumSubscriberTier, Int.self, 1)
        othersEnabled = container.decode(.othersEnabled, Bool.self, false)
        sendChatMessages = container.decode(.sendChatMessages, Bool.self, false)
        cooldown = container.decode(.cooldown, Int?.self, nil)
    }
}

class SettingsChatBotPermissions: Codable {
    var tts: SettingsChatBotPermissionsCommand = .init()
    var fix: SettingsChatBotPermissionsCommand = .init()
    var map: SettingsChatBotPermissionsCommand = .init()
    var alert: SettingsChatBotPermissionsCommand = .init()
    var fax: SettingsChatBotPermissionsCommand = .init()
    var snapshot: SettingsChatBotPermissionsCommand = .init()
    var filter: SettingsChatBotPermissionsCommand = .init()
    var tesla: SettingsChatBotPermissionsCommand = .init()
    var audio: SettingsChatBotPermissionsCommand = .init()
    var reaction: SettingsChatBotPermissionsCommand = .init()
    var scene: SettingsChatBotPermissionsCommand = .init(moderatorsEnabled: false)
    var stream: SettingsChatBotPermissionsCommand = .init(moderatorsEnabled: false)
    var widget: SettingsChatBotPermissionsCommand = .init()
    var location: SettingsChatBotPermissionsCommand = .init()
    var ai: SettingsChatBotPermissionsCommand = .init()
    var twitch: SettingsChatBotPermissionsCommand = .init()
    var migrated: Bool = false

    enum CodingKeys: CodingKey {
        case tts,
             fix,
             map,
             alert,
             fax,
             snapshot,
             filter,
             tesla,
             audio,
             reaction,
             scene,
             stream,
             widget,
             location,
             ai,
             twitch,
             migrated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.tts, tts)
        try container.encode(.fix, fix)
        try container.encode(.map, map)
        try container.encode(.alert, alert)
        try container.encode(.fax, fax)
        try container.encode(.snapshot, snapshot)
        try container.encode(.filter, filter)
        try container.encode(.tesla, tesla)
        try container.encode(.audio, audio)
        try container.encode(.reaction, reaction)
        try container.encode(.scene, scene)
        try container.encode(.stream, stream)
        try container.encode(.widget, widget)
        try container.encode(.location, location)
        try container.encode(.ai, ai)
        try container.encode(.twitch, twitch)
        try container.encode(.migrated, migrated)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tts = container.decode(.tts, SettingsChatBotPermissionsCommand.self, .init())
        fix = container.decode(.fix, SettingsChatBotPermissionsCommand.self, .init())
        map = container.decode(.map, SettingsChatBotPermissionsCommand.self, .init())
        alert = container.decode(.alert, SettingsChatBotPermissionsCommand.self, .init())
        fax = container.decode(.fax, SettingsChatBotPermissionsCommand.self, .init())
        snapshot = container.decode(.snapshot, SettingsChatBotPermissionsCommand.self, .init())
        filter = container.decode(.filter, SettingsChatBotPermissionsCommand.self, .init())
        tesla = container.decode(.tesla, SettingsChatBotPermissionsCommand.self, .init())
        audio = container.decode(.audio, SettingsChatBotPermissionsCommand.self, .init())
        reaction = container.decode(.reaction, SettingsChatBotPermissionsCommand.self, .init())
        scene = container.decode(.scene, SettingsChatBotPermissionsCommand.self, .init())
        stream = container.decode(.stream, SettingsChatBotPermissionsCommand.self, .init())
        widget = container.decode(.widget, SettingsChatBotPermissionsCommand.self, .init())
        location = container.decode(.location, SettingsChatBotPermissionsCommand.self, .init())
        ai = container.decode(.ai, SettingsChatBotPermissionsCommand.self, .init())
        twitch = container.decode(.twitch, SettingsChatBotPermissionsCommand.self, .init())
        migrated = container.decode(.migrated, Bool.self, false)
        if !migrated {
            scene.moderatorsEnabled = false
            stream.moderatorsEnabled = false
            migrated = true
        }
    }
}

class SettingsChatBotAlias: Codable, ObservableObject, Identifiable {
    var id: UUID = .init()
    @Published var alias: String = "!myalias"
    @Published var replacement: String = "!moblin"

    enum CodingKeys: CodingKey {
        case alias,
             replacement
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.alias, alias)
        try container.encode(.replacement, replacement)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alias = container.decode(.alias, String.self, "")
        replacement = container.decode(.replacement, String.self, "")
    }
}

class SettingsChatPredefinedMessage: Codable, Identifiable, ObservableObject {
    static let tagRed = "🌹"
    static let tagGreen = "🐸"
    static let tagBlue = "🐳"
    static let tagYellow = "🐥"
    static let tagOrange = "🦊"
    var id: UUID = .init()
    @Published var text: String = ""
    @Published var blueTag: Bool = false
    @Published var greenTag: Bool = false
    @Published var yellowTag: Bool = false
    @Published var orangeTag: Bool = false
    @Published var redTag: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             text,
             blueTag,
             greenTag,
             yellowTag,
             orangeTag,
             redTag
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.text, text)
        try container.encode(.blueTag, blueTag)
        try container.encode(.greenTag, greenTag)
        try container.encode(.yellowTag, yellowTag)
        try container.encode(.orangeTag, orangeTag)
        try container.encode(.redTag, redTag)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        text = container.decode(.text, String.self, "")
        blueTag = container.decode(.blueTag, Bool.self, false)
        greenTag = container.decode(.greenTag, Bool.self, false)
        yellowTag = container.decode(.yellowTag, Bool.self, false)
        orangeTag = container.decode(.orangeTag, Bool.self, false)
        redTag = container.decode(.redTag, Bool.self, false)
    }

    func tagsString() -> String {
        var tags = ""
        if blueTag {
            tags += Self.tagBlue
        }
        if greenTag {
            tags += Self.tagGreen
        }
        if yellowTag {
            tags += Self.tagYellow
        }
        if orangeTag {
            tags += Self.tagOrange
        }
        if redTag {
            tags += Self.tagRed
        }
        return tags
    }
}

class SettingsChatPredefinedMessagesFilter: Codable, ObservableObject {
    @Published var redTag: Bool = false
    @Published var greenTag: Bool = false
    @Published var blueTag: Bool = false
    @Published var yellowTag: Bool = false
    @Published var orangeTag: Bool = false

    enum CodingKeys: CodingKey {
        case redTag,
             greenTag,
             blueTag,
             yellowTag,
             orangeTag
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.redTag, redTag)
        try container.encode(.greenTag, greenTag)
        try container.encode(.blueTag, blueTag)
        try container.encode(.yellowTag, yellowTag)
        try container.encode(.orangeTag, orangeTag)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        redTag = container.decode(.redTag, Bool.self, false)
        greenTag = container.decode(.greenTag, Bool.self, false)
        blueTag = container.decode(.blueTag, Bool.self, false)
        yellowTag = container.decode(.yellowTag, Bool.self, false)
        orangeTag = container.decode(.orangeTag, Bool.self, false)
    }

    func isEnabled() -> Bool {
        return redTag || greenTag || blueTag || yellowTag || orangeTag
    }
}

class SettingsChatNickname: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var user: String = ""
    @Published var nickname: String = ""

    enum CodingKeys: CodingKey {
        case id,
             user,
             nickname
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.user, user)
        try container.encode(.nickname, nickname)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        user = container.decode(.user, String.self, "")
        nickname = container.decode(.nickname, String.self, "")
    }
}

class SettingsChatNicknames: Codable, ObservableObject {
    @Published var nicknames: [SettingsChatNickname] = []

    enum CodingKeys: CodingKey {
        case nicknames
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.nicknames, nicknames)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nicknames = container.decode(.nicknames, [SettingsChatNickname].self, [])
    }

    func getNickname(user: String) -> String? {
        return nicknames.first(where: { $0.user == user })?.nickname
    }
}

class SettingsOpenAi: Codable, ObservableObject {
    private static let defaultPersonality = "You give fast and short answers."
    @Published var baseUrl: String = "https://generativelanguage.googleapis.com/v1beta/openai"
    @Published var apiKey: String = ""
    @Published var model: String = "gemini-2.0-flash"
    @Published var personality: String

    init(personality: String? = nil) {
        self.personality = personality ?? SettingsOpenAi.defaultPersonality
    }

    enum CodingKeys: CodingKey {
        case baseUrl,
             apiKey,
             model,
             role
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.baseUrl, baseUrl)
        try container.encode(.apiKey, apiKey)
        try container.encode(.model, model)
        try container.encode(.role, personality)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseUrl = container.decode(
            .baseUrl,
            String.self,
            "https://generativelanguage.googleapis.com/v1beta/openai"
        )
        apiKey = container.decode(.apiKey, String.self, "")
        model = container.decode(.model, String.self, "gemini-2.0-flash")
        personality = container.decode(.role, String.self, SettingsOpenAi.defaultPersonality)
    }

    func clone() -> SettingsOpenAi {
        let new = SettingsOpenAi()
        new.baseUrl = baseUrl
        new.apiKey = apiKey
        new.model = model
        new.personality = personality
        return new
    }

    func isConfigured() -> Bool {
        if isValidHttpUrl(url: baseUrl) != nil {
            return false
        }
        if apiKey.isEmpty {
            return false
        }
        if model.isEmpty {
            return false
        }
        if personality.isEmpty {
            return false
        }
        return true
    }
}

enum SettingsChatDisplayStyle: String, Codable, CaseIterable {
    case internationalName
    case internationalNameAndUsername
    case username

    func toString() -> String {
        switch self {
        case .internationalName:
            return String(localized: "International name")
        case .internationalNameAndUsername:
            return String(localized: "International name (Username)")
        case .username:
            return String(localized: "Username")
        }
    }
}

enum SettingsVoiceType: String, Codable, CaseIterable {
    case apple
    case ttsMonster

    init(from decoder: Decoder) throws {
        self = try SettingsVoiceType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .apple
    }
}

class SettingsVoiceApple: Codable {
    var voice: String = ""
}

class SettingsVoiceTtsMonster: Codable {
    var name: String = ""
    var voiceId: String = ""
}

class SettingsVoice: Codable {
    var type: SettingsVoiceType = .apple
    var apple: SettingsVoiceApple = .init()
    var ttsMonster: SettingsVoiceTtsMonster = .init()
}

enum SettingsChatButtonMode: String, Codable, CaseIterable {
    case predefinedMessages
    case moderation

    init(from decoder: Decoder) throws {
        self = try SettingsChatButtonMode(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .predefinedMessages
    }
}

class SettingsChat: Codable, ObservableObject {
    @Published var fontSize: Float = 19.0
    var usernameColor: RgbColor = .init(red: 255, green: 163, blue: 0)
    @Published var usernameColorColor: Color = RgbColor(red: 255, green: 163, blue: 0).color()
    var messageColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    @Published var messageColorColor: Color = RgbColor(red: 255, green: 255, blue: 255).color()
    var backgroundColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var backgroundColorColor: Color = RgbColor(red: 0, green: 0, blue: 0).color()
    @Published var backgroundColorEnabled: Bool = false
    var shadowColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var shadowColorColor: Color = RgbColor(red: 0, green: 0, blue: 0).color()
    @Published var shadowColorEnabled: Bool = true
    @Published var boldUsername: Bool = true
    @Published var boldMessage: Bool = true
    @Published var animatedEmotes: Bool = false
    var timestampColor: RgbColor = .init(red: 180, green: 180, blue: 180)
    @Published var timestampColorColor: Color = RgbColor(red: 180, green: 180, blue: 180).color()
    @Published var timestampColorEnabled: Bool = false
    @Published var height: Double = 0.7
    @Published var width: Double = 1.0
    @Published var maximumAge: Int = 30
    @Published var maximumAgeEnabled: Bool = false
    var meInUsernameColor: Bool = true
    @Published var enabled: Bool = true
    @Published var filters: [SettingsChatFilter] = []
    var textToSpeechEnabled: Bool = false
    @Published var textToSpeechDefaultLanguage: String?
    @Published var textToSpeechDetectLanguagePerMessage: Bool = false
    @Published var textToSpeechSayUsername: Bool = true
    @Published var textToSpeechRate: Float = 0.4
    @Published var textToSpeechSayVolume: Float = 0.6
    @Published var textToSpeechLanguageVoices: [String: SettingsVoice] = .init()
    @Published var textToSpeechSubscribersOnly: Bool = false
    @Published var textToSpeechFilter: Bool = true
    @Published var textToSpeechFilterMentions: Bool = true
    @Published var ttsMonster: SettingsTtsMonster = .init()
    @Published var mirrored: Bool = false
    @Published var botEnabled: Bool = false
    var botCommandPermissions: SettingsChatBotPermissions = .init()
    var botSendLowBatteryWarning: Bool = false
    var botCommandAi: SettingsOpenAi = .init()
    @Published var badges: Bool = true
    var showFirstTimeChatterMessage: Bool = true
    var showNewFollowerMessage: Bool = true
    @Published var bottom: Double = 0.0
    @Published var bottomPoints: Double = 80
    @Published var newMessagesAtTop: Bool = false
    @Published var textToSpeechPauseBetweenMessages: Double = 1.0
    @Published var platform: Bool = true
    @Published var showDeletedMessages: Bool = false
    @Published var aliases: [SettingsChatBotAlias] = []
    @Published var predefinedMessages: [SettingsChatPredefinedMessage] = []
    @Published var predefinedMessagesFilter: SettingsChatPredefinedMessagesFilter = .init()
    @Published var nicknames: SettingsChatNicknames = .init()
    @Published var displayStyle: SettingsChatDisplayStyle = .internationalNameAndUsername

    enum CodingKeys: CodingKey {
        case fontSize,
             usernameColor,
             messageColor,
             backgroundColor,
             backgroundColorEnabled,
             shadowColor,
             shadowColorEnabled,
             boldUsername,
             boldMessage,
             animatedEmotes,
             timestampColor,
             timestampColorEnabled,
             height,
             width,
             maximumAge,
             maximumAgeEnabled,
             meInUsernameColor,
             enabled,
             usernamesToIgnore,
             textToSpeechEnabled,
             textToSpeechDefaultLanguage,
             textToSpeechDetectLanguagePerMessage,
             textToSpeechSayUsername,
             textToSpeechRate,
             textToSpeechSayVolume,
             textToSpeechLanguageVoices,
             textToSpeechSubscribersOnly,
             textToSpeechFilter,
             textToSpeechFilterMentions,
             ttsMonster,
             mirrored,
             botEnabled,
             botCommandPermissions,
             botSendLowBatteryWarning,
             botCommandAi,
             badges,
             showFirstTimeChatterMessage,
             showNewFollowerMessage,
             bottom,
             bottomPoints,
             newMessagesAtTop,
             textToSpeechPauseBetweenMessages,
             platform,
             showDeletedMessages,
             aliases,
             predefinedMessages,
             predefinedMessagesFilter,
             sendMessagesTo,
             nicknames,
             displayStyle
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.fontSize, fontSize)
        try container.encode(.usernameColor, usernameColor)
        try container.encode(.messageColor, messageColor)
        try container.encode(.backgroundColor, backgroundColor)
        try container.encode(.backgroundColorEnabled, backgroundColorEnabled)
        try container.encode(.shadowColor, shadowColor)
        try container.encode(.shadowColorEnabled, shadowColorEnabled)
        try container.encode(.boldUsername, boldUsername)
        try container.encode(.boldMessage, boldMessage)
        try container.encode(.animatedEmotes, animatedEmotes)
        try container.encode(.timestampColor, timestampColor)
        try container.encode(.timestampColorEnabled, timestampColorEnabled)
        try container.encode(.height, height)
        try container.encode(.width, width)
        try container.encode(.maximumAge, maximumAge)
        try container.encode(.maximumAgeEnabled, maximumAgeEnabled)
        try container.encode(.meInUsernameColor, meInUsernameColor)
        try container.encode(.enabled, enabled)
        try container.encode(.usernamesToIgnore, filters)
        try container.encode(.textToSpeechEnabled, textToSpeechEnabled)
        try container.encode(.textToSpeechDefaultLanguage, textToSpeechDefaultLanguage)
        try container.encode(.textToSpeechDetectLanguagePerMessage, textToSpeechDetectLanguagePerMessage)
        try container.encode(.textToSpeechSayUsername, textToSpeechSayUsername)
        try container.encode(.textToSpeechRate, textToSpeechRate)
        try container.encode(.textToSpeechSayVolume, textToSpeechSayVolume)
        try container.encode(.textToSpeechLanguageVoices, textToSpeechLanguageVoices)
        try container.encode(.textToSpeechSubscribersOnly, textToSpeechSubscribersOnly)
        try container.encode(.textToSpeechFilter, textToSpeechFilter)
        try container.encode(.textToSpeechFilterMentions, textToSpeechFilterMentions)
        try container.encode(.ttsMonster, ttsMonster)
        try container.encode(.mirrored, mirrored)
        try container.encode(.botEnabled, botEnabled)
        try container.encode(.botCommandPermissions, botCommandPermissions)
        try container.encode(.botSendLowBatteryWarning, botSendLowBatteryWarning)
        try container.encode(.botCommandAi, botCommandAi)
        try container.encode(.badges, badges)
        try container.encode(.showFirstTimeChatterMessage, showFirstTimeChatterMessage)
        try container.encode(.showNewFollowerMessage, showNewFollowerMessage)
        try container.encode(.bottom, bottom)
        try container.encode(.bottomPoints, bottomPoints)
        try container.encode(.newMessagesAtTop, newMessagesAtTop)
        try container.encode(.textToSpeechPauseBetweenMessages, textToSpeechPauseBetweenMessages)
        try container.encode(.platform, platform)
        try container.encode(.showDeletedMessages, showDeletedMessages)
        try container.encode(.aliases, aliases)
        try container.encode(.predefinedMessages, predefinedMessages)
        try container.encode(.predefinedMessagesFilter, predefinedMessagesFilter)
        try container.encode(.nicknames, nicknames)
        try container.encode(.displayStyle, displayStyle)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontSize = container.decode(.fontSize, Float.self, 19.0)
        usernameColor = container.decode(.usernameColor, RgbColor.self, .init(red: 255, green: 163, blue: 0))
        usernameColorColor = usernameColor.color()
        messageColor = container.decode(.messageColor, RgbColor.self, .init(red: 255, green: 255, blue: 255))
        messageColorColor = messageColor.color()
        backgroundColor = container.decode(.backgroundColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        backgroundColorColor = backgroundColor.color()
        backgroundColorEnabled = container.decode(.backgroundColorEnabled, Bool.self, false)
        shadowColor = container.decode(.shadowColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        shadowColorColor = shadowColor.color()
        shadowColorEnabled = container.decode(.shadowColorEnabled, Bool.self, true)
        boldUsername = container.decode(.boldUsername, Bool.self, true)
        boldMessage = container.decode(.boldMessage, Bool.self, true)
        animatedEmotes = container.decode(.animatedEmotes, Bool.self, false)
        timestampColor = container.decode(
            .timestampColor,
            RgbColor.self,
            .init(red: 180, green: 180, blue: 180)
        )
        timestampColorColor = timestampColor.color()
        timestampColorEnabled = container.decode(.timestampColorEnabled, Bool.self, false)
        height = container.decode(.height, Double.self, 0.7)
        width = container.decode(.width, Double.self, 1.0)
        maximumAge = container.decode(.maximumAge, Int.self, 30)
        maximumAgeEnabled = container.decode(.maximumAgeEnabled, Bool.self, false)
        meInUsernameColor = container.decode(.meInUsernameColor, Bool.self, true)
        enabled = container.decode(.enabled, Bool.self, true)
        filters = container.decode(.usernamesToIgnore, [SettingsChatFilter].self, [])
        textToSpeechEnabled = container.decode(.textToSpeechEnabled, Bool.self, false)
        textToSpeechDefaultLanguage = container.decode(.textToSpeechDefaultLanguage, String?.self, nil)
        textToSpeechDetectLanguagePerMessage = container.decode(
            .textToSpeechDetectLanguagePerMessage,
            Bool.self,
            false
        )
        textToSpeechSayUsername = container.decode(.textToSpeechSayUsername, Bool.self, true)
        textToSpeechRate = container.decode(.textToSpeechRate, Float.self, 0.4)
        textToSpeechSayVolume = container.decode(.textToSpeechSayVolume, Float.self, 0.6)
        textToSpeechLanguageVoices = container.decode(.textToSpeechLanguageVoices,
                                                      [String: SettingsVoice].self,
                                                      .init())
        for (languageCode, voice) in container.decode(
            .textToSpeechLanguageVoices,
            [String: String].self,
            .init()
        ) {
            let settingsVoice = SettingsVoice()
            settingsVoice.apple.voice = voice
            textToSpeechLanguageVoices[languageCode] = settingsVoice
        }
        textToSpeechSubscribersOnly = container.decode(.textToSpeechSubscribersOnly, Bool.self, false)
        textToSpeechFilter = container.decode(.textToSpeechFilter, Bool.self, true)
        textToSpeechFilterMentions = container.decode(.textToSpeechFilterMentions, Bool.self, true)
        ttsMonster = container.decode(.ttsMonster, SettingsTtsMonster.self, .init())
        mirrored = container.decode(.mirrored, Bool.self, false)
        botEnabled = container.decode(.botEnabled, Bool.self, false)
        botCommandPermissions = container.decode(
            .botCommandPermissions,
            SettingsChatBotPermissions.self,
            .init()
        )
        botSendLowBatteryWarning = container.decode(.botSendLowBatteryWarning, Bool.self, false)
        botCommandAi = container.decode(.botCommandAi, SettingsOpenAi.self, .init())
        badges = container.decode(.badges, Bool.self, true)
        showFirstTimeChatterMessage = container.decode(.showFirstTimeChatterMessage, Bool.self, true)
        showNewFollowerMessage = container.decode(.showNewFollowerMessage, Bool.self, true)
        bottom = container.decode(.bottom, Double.self, 0.0)
        bottomPoints = (try? container.decode(Double.self, forKey: .bottomPoints)) ?? min(
            UIScreen.main.bounds.width * bottom,
            200
        )
        newMessagesAtTop = container.decode(.newMessagesAtTop, Bool.self, false)
        textToSpeechPauseBetweenMessages = container.decode(
            .textToSpeechPauseBetweenMessages,
            Double.self,
            1.0
        )
        platform = container.decode(.platform, Bool.self, true)
        showDeletedMessages = container.decode(.showDeletedMessages, Bool.self, false)
        aliases = container.decode(.aliases, [SettingsChatBotAlias].self, [])
        predefinedMessages = container.decode(.predefinedMessages, [SettingsChatPredefinedMessage].self, [])
        predefinedMessagesFilter = container.decode(
            .predefinedMessagesFilter,
            SettingsChatPredefinedMessagesFilter.self,
            .init()
        )
        nicknames = container.decode(.nicknames, SettingsChatNicknames.self, .init())
        displayStyle = container.decode(.displayStyle, SettingsChatDisplayStyle.self, .internationalName)
    }

    func getRotation() -> Double {
        if newMessagesAtTop {
            return 0.0
        } else {
            return 180.0
        }
    }

    func getScaleX() -> Double {
        if newMessagesAtTop {
            return 1.0
        } else {
            return -1.0
        }
    }

    func isMirrored() -> CGFloat {
        if mirrored {
            return -1
        } else {
            return 1
        }
    }
}
