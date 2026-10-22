import Foundation

private let baseUrl = URL(string: "https://api.elevenlabs.io/v1")!

struct ElevenLabsVerifiedLanguage: Codable {
    let language: String
    let locale: String?
}

struct ElevenLabsVoice: Codable {
    let voice_id: String
    let name: String
    let verified_languages: [ElevenLabsVerifiedLanguage]?

    func countryCode(languageCode: String) -> String? {
        guard let locale = verified_languages?.first(where: { $0.language == languageCode })?.locale else {
            return nil
        }
        return Locale(identifier: locale).region?.identifier
    }
}

struct ElevenLabsVoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

struct ElevenLabsGenerateRequest: Codable {
    // periphery:ignore
    let text: String
}

class ElevenLabs {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func getVoices() async -> ElevenLabsVoicesResponse? {
        let request = createRequest(url: baseUrl.appending(components: "voices"), method: "GET")
        guard let (data, response) = try? await httpGet(request: request) else {
            return nil
        }
        if !response.isSuccessful {
            return nil
        }
        return try? JSONDecoder().decode(ElevenLabsVoicesResponse.self, from: data)
    }

    func generateTts(voiceId: String, message: String) async -> Data? {
        var request = createRequest(url: baseUrl.appending(components: "text-to-speech", voiceId),
                                    method: "POST")
        request.setContentType("application/json")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONEncoder().encode(ElevenLabsGenerateRequest(text: message))
        guard let (data, response) = try? await httpGet(request: request) else {
            return nil
        }
        if !response.isSuccessful {
            return nil
        }
        return data
    }

    private func createRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        return request
    }
}
