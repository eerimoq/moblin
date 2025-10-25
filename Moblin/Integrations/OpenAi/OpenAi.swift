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
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setAuthorization("Bearer \(apiKey)")
        request.setContentType("application/json")
        let messages = [
            Message(role: "system", content: role),
            Message(role: "user", content: content),
        ]
        request.httpBody = try? JSONEncoder().encode(Request(model: model, messages: messages))
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
