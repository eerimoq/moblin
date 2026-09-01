import Foundation

private struct Message: Codable {
    // periphery:ignore
    let role: String
    let content: String
}

private struct Choice: Codable {
    var message: Message
}

private struct Request: Codable {
    // periphery:ignore
    let model: String
    // periphery:ignore
    let messages: [Message]
}

private struct Response: Codable {
    let choices: [Choice]
}

private struct ResponseErrorItemError: Codable {
    let message: String
}

private struct ResponseErrorItem: Codable {
    let error: ResponseErrorItemError
}

private struct ResponseError: Codable {
    let errors: [ResponseErrorItem]
}

enum OpenAiError: Error, CustomStringConvertible {
    case malformedRequest
    case requestFailed(String)
    case rateLimited
    case httpError(Int, String)
    case malformedResponse
    case noAnswer

    var description: String {
        switch self {
        case .malformedRequest:
            "malformed request"
        case let .requestFailed(message):
            "request failed: \(message)"
        case .rateLimited:
            "too many requests"
        case let .httpError(statusCode, message):
            "HTTP error \(statusCode): \(message)"
        case .malformedResponse:
            "malformed response"
        case .noAnswer:
            "no answer"
        }
    }
}

@MainActor
class OpenAi {
    private let url: URL
    private let apiKey: String

    init(baseUrl: URL, apiKey: String) {
        url = baseUrl.appending(component: "chat").appending(component: "completions")
        self.apiKey = apiKey
    }

    func ask(_ content: String,
             model: String,
             role: String,
             onComplete: @escaping (Result<String, OpenAiError>) -> Void)
    {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setAuthorization("Bearer \(apiKey)")
        request.setContentType("application/json")
        let messages = [
            Message(role: "system", content: role),
            Message(role: "user", content: content),
        ]
        guard let body = try? JSONEncoder().encode(Request(model: model, messages: messages)) else {
            onComplete(.failure(.malformedRequest))
            return
        }
        request.httpBody = body
        httpRequest(request: request) { data, response, error in
            if let error {
                onComplete(.failure(.requestFailed(error.localizedDescription)))
                return
            }
            guard let response = response?.http, let data else {
                onComplete(.failure(.malformedResponse))
                return
            }
            guard response.isSuccessful else {
                if response.isTooManyRequests {
                    onComplete(.failure(.rateLimited))
                } else {
                    let message = (try? JSONDecoder().decode(ResponseError.self, from: data))?
                        .errors.first?.error.message ?? ""
                    onComplete(.failure(.httpError(response.statusCode, message)))
                }
                return
            }
            guard let choices = try? JSONDecoder().decode(Response.self, from: data).choices else {
                onComplete(.failure(.malformedResponse))
                return
            }
            guard let answer = choices.first?.message.content, !answer.isEmpty else {
                onComplete(.failure(.noAnswer))
                return
            }
            onComplete(.success(answer))
        }
    }
}
