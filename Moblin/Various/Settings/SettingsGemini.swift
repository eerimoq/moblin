import Foundation

class SettingsGemini: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var modelName: String = "gemini-3.5-flash"
    @Published var systemInstruction: String = ""
    @Published var remoteControl: Bool = false
    
    enum CodingKeys: CodingKey {
        case enabled
        case modelName
        case systemInstruction
        case remoteControl
    }
    
    init() {}
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        modelName = container.decode(.modelName, String.self, "gemini-3.5-flash")
        systemInstruction = container.decode(.systemInstruction, String.self, "")
        remoteControl = container.decode(.remoteControl, Bool.self, false)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.modelName, modelName)
        try container.encode(.systemInstruction, systemInstruction)
        try container.encode(.remoteControl, remoteControl)
    }
    
    func storeApiKey(key: String) {
        Keychain(streamId: "gemini", server: "generativelanguage.googleapis.com", logPrefix: "gemini: auth").store(value: key)
    }
    
    func loadApiKey() -> String {
        return Keychain(streamId: "gemini", server: "generativelanguage.googleapis.com", logPrefix: "gemini: auth").load() ?? ""
    }
    
    func removeApiKey() {
        Keychain(streamId: "gemini", server: "generativelanguage.googleapis.com", logPrefix: "gemini: auth").remove()
    }
}
