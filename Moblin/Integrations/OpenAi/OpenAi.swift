import Foundation

private struct Message: Codable {
    var role: String
    var content: String
}

private struct Choice: Codable {
    var message: Message
}

private struct Request: Codable {
    var model: String
    var messages: [Message]
}

private struct Response: Codable {
    var choices: [Choice]
}

class OpenAi {
    private let url: URL
    private let apiKey: String

    init(baseUrl: URL, apiKey: String) {
        url = baseUrl.appending(component: "chat").appending(component: "completions")
        self.apiKey = apiKey
    }

    func ask(_ content: String, model: String, role: String, onComplete: @escaping (String?) -> Void) {
        let messages = [
            Message(role: "system", content: role),
            Message(role: "user", content: content),
        ]
        let aiRequest = Request(model: model, messages: messages)
        guard let body = try? String(bytes: JSONEncoder().encode(aiRequest), encoding: .utf8) else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.utf8Data
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, let data, response?.http?.isSuccessful == true else {
                onComplete(nil)
                return
            }
            let answers = try? JSONDecoder().decode(Response.self, from: data)
            onComplete(answers?.choices.first?.message.content)
        }
        .resume()
    }
}
