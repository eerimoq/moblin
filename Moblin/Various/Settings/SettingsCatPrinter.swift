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
    @Published var printEvents: Bool = false
    @Published var printEventSubscriptions: Bool = true
    @Published var printEventGiftedSubscriptions: Bool = true
    @Published var printEventResubscriptions: Bool = true
    @Published var printEventRaidsAndHosts: Bool = true
    @Published var printEventRewards: Bool = true
    @Published var printEventBitsAndKicks: Bool = true

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
             printEvents,
             printEventSubscriptions,
             printEventGiftedSubscriptions,
             printEventResubscriptions,
             printEventRaidsAndHosts,
             printEventRewards,
             printEventBitsAndKicks
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
        try container.encode(.printEvents, printEvents)
        try container.encode(.printEventSubscriptions, printEventSubscriptions)
        try container.encode(.printEventGiftedSubscriptions, printEventGiftedSubscriptions)
        try container.encode(.printEventResubscriptions, printEventResubscriptions)
        try container.encode(.printEventRaidsAndHosts, printEventRaidsAndHosts)
        try container.encode(.printEventRewards, printEventRewards)
        try container.encode(.printEventBitsAndKicks, printEventBitsAndKicks)
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
        printEvents = container.decode(.printEvents, Bool.self, false)
        printEventSubscriptions = container.decode(.printEventSubscriptions, Bool.self, true)
        printEventGiftedSubscriptions = container.decode(.printEventGiftedSubscriptions, Bool.self, true)
        printEventResubscriptions = container.decode(.printEventResubscriptions, Bool.self, true)
        printEventRaidsAndHosts = container.decode(.printEventRaidsAndHosts, Bool.self, true)
        printEventRewards = container.decode(.printEventRewards, Bool.self, true)
        printEventBitsAndKicks = container.decode(.printEventBitsAndKicks, Bool.self, true)
    }

    func isEventTypeEnabled(_ eventType: CatPrinterEventType) -> Bool {
        switch eventType {
        case .subscription: printEventSubscriptions
        case .giftedSubscription: printEventGiftedSubscriptions
        case .resubscription: printEventResubscriptions
        case .raid, .host: printEventRaidsAndHosts
        case .reward: printEventRewards
        case .bitsAndKicks: printEventBitsAndKicks
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
