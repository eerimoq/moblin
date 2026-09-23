import AVFoundation
import Collections
import Foundation

enum SettingsReaction: Codable, CaseIterable {
    case fireworks
    case balloons
    case hearts
    case confetti
    case lasers
    case rain
    case glasses
    case sparkle

    @available(iOS 17, *)
    init?(value: String?) {
        switch value {
        case "fireworks":
            self = .fireworks
        case "balloons":
            self = .balloons
        case "hearts":
            self = .hearts
        case "confetti":
            self = .confetti
        case "lasers":
            self = .lasers
        case "rain":
            self = .rain
        case "glasses":
            self = .glasses
        case "sparkle":
            self = .sparkle
        default:
            return nil
        }
    }

    @available(iOS 17, *)
    func toSystem() -> AVCaptureReactionType? {
        switch self {
        case .fireworks:
            .fireworks
        case .balloons:
            .balloons
        case .hearts:
            .heart
        case .confetti:
            .confetti
        case .lasers:
            .lasers
        case .rain:
            .rain
        default:
            nil
        }
    }

    func toString() -> String {
        switch self {
        case .fireworks:
            String(localized: "Fireworks")
        case .balloons:
            String(localized: "Balloons")
        case .hearts:
            String(localized: "Hearts")
        case .confetti:
            String(localized: "Confetti")
        case .lasers:
            String(localized: "Lasers")
        case .rain:
            String(localized: "Rain")
        case .glasses:
            String(localized: "Glasses")
        case .sparkle:
            String(localized: "Sparkle")
        }
    }
}

enum SettingsMacrosActionFunction: String, CaseIterable, Codable {
    case scene = "Scene"
    case zoom = "Zoom"
    case filters = "Filters"
    case reaction = "Reaction"
    case enableDisableScenes = "Enable/disable scenes"
    case record = "Record"
    case snapshot = "Snapshot"
    case mute = "Mute"
    case torch = "Torch"
    case autoSceneSwitcher = "Auto scene switcher"
    case djiDevices = "DJI devices"
    case gimbalPreset = "Move to gimbal preset"
    case sendChatMessage = "Send chat message"
    case sendTwitchShoutout = "Send Twitch shoutout"
    case delay = "Delay"
    case waitForEvent = "Wait for event"
    case ifCondition = "If"
    case macro = "Macro"

    func toString() -> String {
        switch self {
        case .scene:
            String(localized: "Scene")
        case .zoom:
            String(localized: "Zoom")
        case .filters:
            String(localized: "Filters")
        case .reaction:
            String(localized: "Reaction")
        case .enableDisableScenes:
            String(localized: "Scenes")
        case .record:
            String(localized: "Record")
        case .snapshot:
            String(localized: "Snapshot")
        case .mute:
            String(localized: "Mute")
        case .torch:
            String(localized: "Torch")
        case .autoSceneSwitcher:
            String(localized: "Auto scene switcher")
        case .djiDevices:
            String(localized: "DJI devices")
        case .gimbalPreset:
            String(localized: "Move to gimbal preset")
        case .sendChatMessage:
            String(localized: "Send chat message")
        case .sendTwitchShoutout:
            String(localized: "Send Twitch shoutout")
        case .delay:
            String(localized: "Delay")
        case .waitForEvent:
            String(localized: "Wait for event")
        case .ifCondition:
            String(localized: "If")
        case .macro:
            String(localized: "Run macro")
        }
    }
}

enum SettingsMacrosEvent: String, Codable, CaseIterable {
    case twitchFollow = "Twitch follow"
    case twitchSubscription = "Twitch subscription"
    case twitchGiftSubscription = "Twitch gift subscription"
    case twitchResubscription = "Twitch resubscription"
    case twitchReward = "Twitch reward"
    case twitchRaid = "Twitch raid"
    case twitchCheer = "Twitch cheer"
    case twitchWatchStreak = "Twitch watch streak"
    case kickSubscription = "Kick subscription"
    case kickGiftSubscriptions = "Kick gift subscriptions"
    case kickReward = "Kick reward"
    case kickRaid = "Kick raid"
    case kickKicks = "Kick kicks"
    case goLive = "Stream started"
    case end = "Stream stopped"
    case startRecording = "Recording started"
    case stopRecording = "Recording stopped"
    case switchScene = "Scene switched"

    func toString() -> String {
        switch self {
        case .twitchFollow:
            String(localized: "Twitch follow")
        case .twitchSubscription:
            String(localized: "Twitch subscription")
        case .twitchGiftSubscription:
            String(localized: "Twitch gift subscription")
        case .twitchResubscription:
            String(localized: "Twitch resubscription")
        case .twitchReward:
            String(localized: "Twitch reward")
        case .twitchRaid:
            String(localized: "Twitch raid")
        case .twitchCheer:
            String(localized: "Twitch bits")
        case .twitchWatchStreak:
            String(localized: "Twitch watch streak")
        case .kickSubscription:
            String(localized: "Kick subscription")
        case .kickGiftSubscriptions:
            String(localized: "Kick gift subscriptions")
        case .kickReward:
            String(localized: "Kick reward")
        case .kickRaid:
            String(localized: "Kick raid")
        case .kickKicks:
            String(localized: "Kick kicks")
        case .goLive:
            String(localized: "Go live")
        case .end:
            String(localized: "End")
        case .startRecording:
            String(localized: "Start recording")
        case .stopRecording:
            String(localized: "Stop recording")
        case .switchScene:
            String(localized: "Switch scene")
        }
    }

    func minimumAmountTitle() -> String? {
        switch self {
        case .twitchGiftSubscription, .kickGiftSubscriptions:
            String(localized: "Minimum subscriptions")
        case .twitchResubscription, .kickSubscription:
            String(localized: "Minimum months")
        case .twitchRaid, .kickRaid:
            String(localized: "Minimum viewers")
        case .twitchCheer:
            String(localized: "Minimum bits")
        case .twitchWatchStreak:
            String(localized: "Minimum watch streak")
        case .kickKicks:
            String(localized: "Minimum kicks")
        default:
            nil
        }
    }

    func variables() -> [MacroVariable] {
        switch self {
        case .twitchFollow:
            [.twitchFollowUser]
        case .twitchSubscription:
            [.twitchSubscriptionUser]
        case .twitchGiftSubscription:
            [.twitchGiftSubscriptionUser]
        case .twitchResubscription:
            [.twitchResubscriptionUser]
        case .twitchReward:
            [.twitchRewardUser]
        case .twitchWatchStreak:
            [.twitchWatchStreakUser]
        case .twitchCheer:
            [.twitchCheerUser]
        case .twitchRaid:
            [.twitchRaidChannelId, .twitchRaidChannelName]
        default:
            []
        }
    }

    func textTitle() -> String? {
        switch self {
        case .twitchReward, .kickReward:
            String(localized: "Reward")
        default:
            nil
        }
    }
}

enum MacroVariable: String {
    case twitchFollowUser
    case twitchSubscriptionUser
    case twitchGiftSubscriptionUser
    case twitchResubscriptionUser
    case twitchRewardUser
    case twitchWatchStreakUser
    case twitchCheerUser
    case twitchRaidChannelId
    case twitchRaidChannelName

    func toString() -> String {
        "{\(rawValue)}"
    }

    func description() -> String {
        switch self {
        case .twitchFollowUser:
            String(localized: "Name of the user who followed")
        case .twitchSubscriptionUser:
            String(localized: "Name of the user who subscribed")
        case .twitchGiftSubscriptionUser:
            String(localized: "Name of the user who gifted subscriptions")
        case .twitchResubscriptionUser:
            String(localized: "Name of the user who resubscribed")
        case .twitchRewardUser:
            String(localized: "Name of the user who redeemed the reward")
        case .twitchWatchStreakUser:
            String(localized: "Name of the user who shared the watch streak")
        case .twitchCheerUser:
            String(localized: "Name of the user who cheered")
        case .twitchRaidChannelId:
            String(localized: "Id of the raiding channel")
        case .twitchRaidChannelName:
            String(localized: "Name of the raiding channel")
        }
    }
}

class MacroVariables {
    private var values: [MacroVariable: String] = [:]

    func set(_ variables: [MacroVariable: String]) {
        values.merge(variables) { _, new in new }
    }

    func get(_ variable: MacroVariable) -> String? {
        values[variable]
    }

    func removeAll() {
        values.removeAll()
    }

    func substitute(_ text: String) -> String {
        var text = text
        for (variable, value) in values {
            text = text.replacingOccurrences(of: variable.toString(), with: value, options: .caseInsensitive)
        }
        return text
    }
}

struct MacroEvent {
    let event: SettingsMacrosEvent
    var amount: Int = 0
    var text: String = ""
    var sceneId: UUID?
    var variables: [MacroVariable: String] = [:]
}

enum SettingsMacrosActionIfComparison: String, CaseIterable, Codable {
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessEqual = "<="
    case greaterThan = ">"
    case greaterEqual = ">="
    case contains = "Contains"

    func toString() -> String {
        switch self {
        case .contains:
            String(localized: "Contains")
        default:
            rawValue
        }
    }

    func evaluate(value: String, otherValue: String) -> Bool {
        if self == .contains {
            return value.localizedCaseInsensitiveContains(otherValue)
        }
        if let value = toNumber(value), let otherValue = toNumber(otherValue) {
            return compare(value < otherValue ? .orderedAscending :
                value > otherValue ? .orderedDescending : .orderedSame)
        }
        return compare(value.localizedCaseInsensitiveCompare(otherValue))
    }

    private func compare(_ order: ComparisonResult) -> Bool {
        switch self {
        case .equal:
            order == .orderedSame
        case .notEqual:
            order != .orderedSame
        case .lessThan:
            order == .orderedAscending
        case .lessEqual:
            order != .orderedDescending
        case .greaterThan:
            order == .orderedDescending
        case .greaterEqual:
            order != .orderedAscending
        case .contains:
            false
        }
    }

    private func toNumber(_ value: String) -> Double? {
        let value = value.trimmingCharacters(in: .whitespaces)
        return Double(value.prefix(while: { $0.isNumber || $0 == "." || $0 == "-" || $0 == "+" }))
    }
}

class SettingsMacrosAction: Identifiable, Codable, ObservableObject {
    var id: UUID = .init()
    @Published var function: SettingsMacrosActionFunction?
    @Published var sceneId: UUID?
    @Published var sceneIds: Set<UUID> = []
    @Published var autoSceneSwitcherId: UUID?
    @Published var zoomX: Float = 1
    @Published var gimbalPresetId: UUID?
    @Published var chatMessage: String = ""
    @Published var delay: Double = 3
    @Published var macroId: UUID?
    @Published var djiDevices: Set<UUID> = []
    @Published var filters: Set<SettingsQuickButtonType> = []
    @Published var record: Bool = true
    @Published var mute: Bool = true
    @Published var torch: Bool = true
    @Published var reaction: SettingsReaction = .fireworks
    @Published var ifValue: String = ""
    @Published var ifComparison: SettingsMacrosActionIfComparison = .equal
    @Published var ifOtherValue: String = ""
    @Published var ifRunCount: Int = 1
    @Published var event: SettingsMacrosEvent = .twitchFollow
    @Published var eventMinimumAmount: Int = 0
    @Published var eventText: String = ""
    @Published var eventSceneId: UUID?
    var needsWeather: Bool = false
    var needsGeography: Bool = false
    var needsGForce: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case function
        case sceneId
        case sceneIds
        case autoSceneSwitcherId
        case zoomX
        case gimbalPresetId
        case chatMessage
        case delay
        case macroId
        case djiDevices
        case filters
        case record
        case mute
        case torch
        case reaction
        case ifValue
        case ifComparison
        case ifOtherValue
        case ifRunCount
        case event
        case eventMinimumAmount
        case eventText
        case eventSceneId
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
        try container.encode(.sceneIds, sceneIds)
        try container.encode(.autoSceneSwitcherId, autoSceneSwitcherId)
        try container.encode(.zoomX, zoomX)
        try container.encode(.gimbalPresetId, gimbalPresetId)
        try container.encode(.chatMessage, chatMessage)
        try container.encode(.delay, delay)
        try container.encode(.macroId, macroId)
        try container.encode(.djiDevices, djiDevices)
        try container.encode(.filters, filters)
        try container.encode(.record, record)
        try container.encode(.mute, mute)
        try container.encode(.torch, torch)
        try container.encode(.reaction, reaction)
        try container.encode(.ifValue, ifValue)
        try container.encode(.ifComparison, ifComparison)
        try container.encode(.ifOtherValue, ifOtherValue)
        try container.encode(.ifRunCount, ifRunCount)
        try container.encode(.event, event)
        try container.encode(.eventMinimumAmount, eventMinimumAmount)
        try container.encode(.eventText, eventText)
        try container.encode(.eventSceneId, eventSceneId)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        function = container.decode(.function, SettingsMacrosActionFunction?.self, nil)
        sceneId = container.decode(.sceneId, UUID?.self, nil)
        sceneIds = container.decode(.sceneIds, Set<UUID>.self, [])
        autoSceneSwitcherId = container.decode(.autoSceneSwitcherId, UUID?.self, nil)
        zoomX = container.decode(.zoomX, Float.self, 1)
        gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
        chatMessage = container.decode(.chatMessage, String.self, "")
        delay = container.decode(.delay, Double.self, 3)
        macroId = container.decode(.macroId, UUID?.self, nil)
        djiDevices = container.decode(.djiDevices, Set<UUID>.self, [])
        filters = container.decode(.filters, Set<SettingsQuickButtonType>.self, [])
        record = container.decode(.record, Bool.self, true)
        mute = container.decode(.mute, Bool.self, true)
        torch = container.decode(.torch, Bool.self, true)
        reaction = container.decode(.reaction, SettingsReaction.self, .fireworks)
        ifValue = container.decode(.ifValue, String.self, "")
        ifComparison = container.decode(.ifComparison, SettingsMacrosActionIfComparison.self, .equal)
        ifOtherValue = container.decode(.ifOtherValue, String.self, "")
        ifRunCount = container.decode(.ifRunCount, Int.self, 1)
        event = container.decode(.event, SettingsMacrosEvent.self, .twitchFollow)
        eventMinimumAmount = container.decode(.eventMinimumAmount, Int.self, 0)
        eventText = container.decode(.eventText, String.self, "")
        eventSceneId = container.decode(.eventSceneId, UUID?.self, nil)
    }

    func matches(event: MacroEvent) -> Bool {
        guard event.event == self.event, event.amount >= eventMinimumAmount else {
            return false
        }
        if let eventSceneId, event.sceneId != eventSceneId {
            return false
        }
        let text = eventText.trim()
        return text.isEmpty || event.text.trim().caseInsensitiveCompare(text) == .orderedSame
    }
}

enum SettingsMacrosMacroRepeatMode: String, Codable, CaseIterable {
    case off
    case count
    case forever

    func toString() -> String {
        switch self {
        case .off:
            String(localized: "Off")
        case .count:
            String(localized: "Count")
        case .forever:
            String(localized: "Forever")
        }
    }
}

class SettingsMacrosMacro: Identifiable, Codable, ObservableObject, Named {
    static let baseName = String(localized: "My macro")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var actions: [SettingsMacrosAction] = []
    @Published var running: Bool = false
    @Published var finished: Bool = false
    @Published var repeatMode: SettingsMacrosMacroRepeatMode = .off
    @Published var repeatCount: Int = 5
    @Published var closePanelOnRun: Bool = false
    @Published var runAtAppStart: Bool = false
    let variables = MacroVariables()
    var nextActionIndex: Int = 0
    var waitingForEventAction: SettingsMacrosAction?
    var eventQueue: Deque<MacroEvent> = []
    var repeatCurrentCount: Int = 0
    var delayed: Bool = false
    let delayTimer = MainTimer()
    let finishedTimer = MainTimer()
    var stack: [SettingsMacrosMacro] = []

    init() {}

    enum CodingKeys: CodingKey {
        case id
        case name
        case actions
        case repeatMode
        case repeatCount
        case closePanelOnRun
        case runAtAppStart
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.actions, actions)
        try container.encode(.repeatMode, repeatMode)
        try container.encode(.repeatCount, repeatCount)
        try container.encode(.closePanelOnRun, closePanelOnRun)
        try container.encode(.runAtAppStart, runAtAppStart)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        actions = container.decode(.actions, [SettingsMacrosAction].self, [])
        repeatMode = container.decode(.repeatMode, SettingsMacrosMacroRepeatMode.self, .off)
        repeatCount = container.decode(.repeatCount, Int.self, 5)
        closePanelOnRun = container.decode(.closePanelOnRun, Bool.self, false)
        runAtAppStart = container.decode(.runAtAppStart, Bool.self, false)
    }

    func copy() -> SettingsMacrosMacro {
        let new = SettingsMacrosMacro()
        new.id = id
        new.name = name
        new.repeatMode = repeatMode
        new.repeatCount = repeatCount
        new.actions = actions
        return new
    }
}

class SettingsMacros: Codable, ObservableObject {
    @Published var macros: [SettingsMacrosMacro] = []

    init() {}

    enum CodingKeys: CodingKey {
        case macros
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.macros, macros)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        macros = container.decode(.macros, [SettingsMacrosMacro].self, [])
    }
}
