import Foundation

enum CatPrinterEventType {
    case subscription
    case giftedSubscription
    case resubscription
    case raid
    case host
    case reward
    case bitsAndKicks
}

class SettingsCatPrinter: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My printer")
    var id: UUID = .init()
    @Published var name: String = ""
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var printChat: Bool = true
    @Published var faxMeowSound: Bool = true
    @Published var printSnapshots: Bool = true
    @Published var printTwitchEvents: Bool = false
    @Published var printEventTwitchSubscriptions: Bool = true
    @Published var printEventTwitchGiftedSubscriptions: Bool = true
    @Published var printEventTwitchResubscriptions: Bool = true
    @Published var printEventTwitchRaidsAndHosts: Bool = true
    @Published var printEventTwitchRewards: Bool = true
    @Published var printEventTwitchBits: Bool = true
    @Published var printKickEvents: Bool = false
    @Published var printEventKickSubscriptions: Bool = true
    @Published var printEventKickGiftedSubscriptions: Bool = true
    @Published var printEventKickRaidsAndHosts: Bool = true
    @Published var printEventKickRewards: Bool = true
    @Published var printEventKickKicks: Bool = true

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             enabled,
             bluetoothPeripheralName,
             bluetoothPeripheralId,
             printChat,
             faxMeowSound,
             printSnapshots,
             printTwitchEvents,
             printEventTwitchSubscriptions,
             printEventTwitchGiftedSubscriptions,
             printEventTwitchResubscriptions,
             printEventTwitchRaidsAndHosts,
             printEventTwitchRewards,
             printEventTwitchBits,
             printKickEvents,
             printEventKickSubscriptions,
             printEventKickGiftedSubscriptions,
             printEventKickRaidsAndHosts,
             printEventKickRewards,
             printEventKickKicks
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.enabled, enabled)
        try container.encode(.bluetoothPeripheralName, bluetoothPeripheralName)
        try container.encode(.bluetoothPeripheralId, bluetoothPeripheralId)
        try container.encode(.printChat, printChat)
        try container.encode(.faxMeowSound, faxMeowSound)
        try container.encode(.printSnapshots, printSnapshots)
        try container.encode(.printTwitchEvents, printTwitchEvents)
        try container.encode(.printEventTwitchSubscriptions, printEventTwitchSubscriptions)
        try container.encode(.printEventTwitchGiftedSubscriptions, printEventTwitchGiftedSubscriptions)
        try container.encode(.printEventTwitchResubscriptions, printEventTwitchResubscriptions)
        try container.encode(.printEventTwitchRaidsAndHosts, printEventTwitchRaidsAndHosts)
        try container.encode(.printEventTwitchRewards, printEventTwitchRewards)
        try container.encode(.printEventTwitchBits, printEventTwitchBits)
        try container.encode(.printKickEvents, printKickEvents)
        try container.encode(.printEventKickSubscriptions, printEventKickSubscriptions)
        try container.encode(.printEventKickGiftedSubscriptions, printEventKickGiftedSubscriptions)
        try container.encode(.printEventKickRaidsAndHosts, printEventKickRaidsAndHosts)
        try container.encode(.printEventKickRewards, printEventKickRewards)
        try container.encode(.printEventKickKicks, printEventKickKicks)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        printChat = container.decode(.printChat, Bool.self, true)
        faxMeowSound = container.decode(.faxMeowSound, Bool.self, true)
        printSnapshots = container.decode(.printSnapshots, Bool.self, true)
        printTwitchEvents = container.decode(.printTwitchEvents, Bool.self, false)
        printEventTwitchSubscriptions = container.decode(.printEventTwitchSubscriptions, Bool.self, true)
        printEventTwitchGiftedSubscriptions = container.decode(.printEventTwitchGiftedSubscriptions, Bool.self, true)
        printEventTwitchResubscriptions = container.decode(.printEventTwitchResubscriptions, Bool.self, true)
        printEventTwitchRaidsAndHosts = container.decode(.printEventTwitchRaidsAndHosts, Bool.self, true)
        printEventTwitchRewards = container.decode(.printEventTwitchRewards, Bool.self, true)
        printEventTwitchBits = container.decode(.printEventTwitchBits, Bool.self, true)
        printKickEvents = container.decode(.printKickEvents, Bool.self, false)
        printEventKickSubscriptions = container.decode(.printEventKickSubscriptions, Bool.self, true)
        printEventKickGiftedSubscriptions = container.decode(.printEventKickGiftedSubscriptions, Bool.self, true)
        printEventKickRaidsAndHosts = container.decode(.printEventKickRaidsAndHosts, Bool.self, true)
        printEventKickRewards = container.decode(.printEventKickRewards, Bool.self, true)
        printEventKickKicks = container.decode(.printEventKickKicks, Bool.self, true)
    }

    func isEventTypeEnabled(_ eventType: CatPrinterEventType, platform: String) -> Bool {
        let isTwitch = platform.lowercased() == "twitch"
        switch eventType {
        case .subscription:
            return isTwitch ? printEventTwitchSubscriptions : printEventKickSubscriptions
        case .giftedSubscription:
            return isTwitch ? printEventTwitchGiftedSubscriptions : printEventKickGiftedSubscriptions
        case .resubscription:
            return isTwitch ? printEventTwitchResubscriptions : false
        case .raid, .host:
            return isTwitch ? printEventTwitchRaidsAndHosts : printEventKickRaidsAndHosts
        case .reward:
            return isTwitch ? printEventTwitchRewards : printEventKickRewards
        case .bitsAndKicks:
            return isTwitch ? printEventTwitchBits : printEventKickKicks
        }
    }
}

class SettingsCatPrinters: Codable, ObservableObject {
    @Published var devices: [SettingsCatPrinter] = []
    @Published var backgroundPrinting: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case devices,
             backgroundPrinting
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.devices, devices)
        try container.encode(.backgroundPrinting, backgroundPrinting)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = container.decode(.devices, [SettingsCatPrinter].self, [])
        backgroundPrinting = container.decode(.backgroundPrinting, Bool.self, false)
    }
}
