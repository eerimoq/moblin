import Foundation

private let baseUrl = URL(string: "https://api.console.tts.monster")!

struct TtsMonsterVoice: Codable {
    var voice_id: String
    var name: String
    var sample: String
    var language: String?
    var metadata: String?

    func countryCode() -> String? {
        guard let part = metadata?.split(separator: "|").first else {
            return nil
        }
        return Locale(identifier: String(part)).region?.identifier
    }

    func languageCode() -> String? {
        if let language {
            return Locale(identifier: language).language.languageCode?.identifier
        } else if let metadata {
            guard let part = metadata.split(separator: "|").first else {
                return nil
            }
            return Locale(identifier: String(part)).language.languageCode?.identifier
        } else {
            return nil
        }
    }
}

struct TtsMonsterVoicesResponse: Codable {
    var voices: [TtsMonsterVoice]
    var customVoices: [TtsMonsterVoice]

    func allVoices() -> [TtsMonsterVoice] {
        return customVoices + voices
    }
}

struct TtsMonsterGenerateRequest: Codable {
    var voice_id: String
    var message: String
}

struct TtsMonsterGenerateResponse: Codable {
    var url: String
}

class TtsMonster {
    private let apiToken: String

    init(apiToken: String) {
        self.apiToken = apiToken
    }

    func getVoices() async -> TtsMonsterVoicesResponse? {
        let request = createRequest(component: "voices")
        guard let (data, response) = try? await httpGet(request: request) else {
            return nil
        }
        if !response.isSuccessful {
            return nil
        }
        return try? JSONDecoder().decode(TtsMonsterVoicesResponse.self, from: data)
    }

    func generateTts(voiceId: String, message: String) async -> Data? {
        var request = createRequest(component: "generate")
        request.httpBody = try? JSONEncoder().encode(TtsMonsterGenerateRequest(voice_id: voiceId, message: message))
        guard let (data, response) = try? await httpGet(request: request) else {
            return nil
        }
        if !response.isSuccessful {
            return nil
        }
        guard let response = try? JSONDecoder().decode(TtsMonsterGenerateResponse.self, from: data) else {
            return nil
        }
        guard let url = URL(string: response.url) else {
            return nil
        }
        guard let (data, response) = try? await httpGet(from: url) else {
            return nil
        }
        if !response.isSuccessful {
            return nil
        }
        return data
    }

    private func createRequest(component: String) -> URLRequest {
        var request = URLRequest(url: baseUrl.appending(components: component))
        request.httpMethod = "POST"
        request.setAuthorization(apiToken)
        return request
    }
}
