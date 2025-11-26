import Foundation

class SettingsCatPrinter: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My printer")
    var id: UUID = .init()
    @Published var name: String = ""
    @Published var enabled: Bool = false
    @Published var bluetoothPeripheralName: String?
    @Published var bluetoothPeripheralId: UUID?
    @Published var printChat: Bool = false
    @Published var faxMeowSound: Bool = true
    @Published var printSnapshots: Bool = true
    @Published var printTwitch: SettingsTwitchAlerts = .init()
    @Published var printKick: SettingsKickAlerts = .init()

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
             printTwitch,
             printKick
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
        try container.encode(.printTwitch, printTwitch)
        try container.encode(.printKick, printKick)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        enabled = container.decode(.enabled, Bool.self, false)
        bluetoothPeripheralName = try? container.decode(String.self, forKey: .bluetoothPeripheralName)
        bluetoothPeripheralId = try? container.decode(UUID.self, forKey: .bluetoothPeripheralId)
        printChat = container.decode(.printChat, Bool.self, false)
        faxMeowSound = container.decode(.faxMeowSound, Bool.self, true)
        printSnapshots = container.decode(.printSnapshots, Bool.self, true)
        printTwitch = container.decode(.printTwitch, SettingsTwitchAlerts.self, .init())
        printKick = container.decode(.printKick, SettingsKickAlerts.self, .init())
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
