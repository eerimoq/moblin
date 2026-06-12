import Foundation

class SettingsGemini: Codable, ObservableObject {
    @Published var enabled: Bool = false
    @Published var modelName: String = "gemini-3.5-flash"
    @Published var systemInstruction: String = ""
    @Published var remoteControl: Bool = false
    @Published var apiKey: String = ""
    
    enum CodingKeys: CodingKey {
        case enabled
        case modelName
        case systemInstruction
        case remoteControl
        case apiKey
    }
    
    init() {}
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, false)
        modelName = container.decode(.modelName, String.self, "gemini-3.5-flash")
        systemInstruction = container.decode(.systemInstruction, String.self, "")
        remoteControl = container.decode(.remoteControl, Bool.self, false)
        apiKey = container.decode(.apiKey, String.self, "")
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.modelName, modelName)
        try container.encode(.systemInstruction, systemInstruction)
        try container.encode(.remoteControl, remoteControl)
        try container.encode(.apiKey, apiKey)
    }
    
    func storeApiKey(key: String) {
        self.apiKey = key
        Keychain(streamId: "gemini", server: "generativelanguage.googleapis.com", logPrefix: "gemini: auth").store(value: key)
    }
    
    func loadApiKey() -> String {
        let keychainKey = Keychain(streamId: "gemini", server: "generativelanguage.googleapis.com", logPrefix: "gemini: auth").load() ?? ""
        if !keychainKey.isEmpty {
            return keychainKey
        }
        return apiKey
    }
    
    func removeApiKey() {
        self.apiKey = ""
        Keychain(streamId: "gemini", server: "generativelanguage.googleapis.com", logPrefix: "gemini: auth").remove()
    }
}
