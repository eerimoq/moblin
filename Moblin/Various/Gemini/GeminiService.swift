import Foundation

enum GeminiActionType: String {
    case changeScene = "changeScene"
    case muteMicrophone = "muteMicrophone"
    case toggleTorch = "toggleTorch"
    case displayOverlayImage = "displayOverlayImage"
    case showOverlayText = "showOverlayText"
    case unknown
}

struct GeminiAction {
    let type: GeminiActionType
    let parameters: [String: Any]
}

actor GeminiService {
    private let session = URLSession.shared
    
    // Conversation history to maintain context
    private struct ChatMessage: Encodable {
        struct Part: Encodable {
            let text: String
        }
        let role: String
        let parts: [Part]
    }
    private var conversationHistory: [ChatMessage] = []
    
    // Structure of Gemini Request
    private struct GeminiRequest: Encodable {
        struct SystemInstruction: Encodable {
            struct Part: Encodable {
                let text: String
            }
            let parts: [Part]
        }
        
        struct Tool: Encodable {
            struct FunctionDeclaration: Encodable {
                struct Parameters: Encodable {
                    let type: String
                    let properties: [String: Property]
                    let required: [String]
                }
                
                struct Property: Encodable {
                    let type: String
                    let description: String
                }
                
                let name: String
                let description: String
                let parameters: Parameters
            }
            struct GoogleSearch: Encodable {}
            
            let functionDeclarations: [FunctionDeclaration]?
            let googleSearch: GoogleSearch?
            
            enum CodingKeys: String, CodingKey {
                case functionDeclarations
                case googleSearch = "google_search"
            }
        }
        
        let contents: [ChatMessage]
        let systemInstruction: SystemInstruction?
        let tools: [Tool]?
    }
    
    // Structure of Gemini Response
    private struct GeminiResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    struct FunctionCall: Decodable {
                        let name: String
                        let args: [String: StringOrIntOrBool]?
                    }
                    let text: String?
                    let functionCall: FunctionCall?
                }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }
    
    private enum StringOrIntOrBool: Decodable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let val = try? container.decode(String.self) {
                self = .string(val)
            } else if let val = try? container.decode(Int.self) {
                self = .int(val)
            } else if let val = try? container.decode(Double.self) {
                self = .double(val)
            } else if let val = try? container.decode(Bool.self) {
                self = .bool(val)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid type")
            }
        }
        
        func toAny() -> Any {
            switch self {
            case .string(let s): return s
            case .int(let i): return i
            case .double(let d): return d
            case .bool(let b): return b
            }
        }
    }
    
    func executeCommand(
        text: String,
        apiKey: String,
        modelName: String,
        systemInstruction: String?,
        completion: @escaping (Result<([GeminiAction], String?), Error>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "GeminiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is empty"])))
            return
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "GeminiService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Append user prompt to history
        conversationHistory.append(ChatMessage(role: "user", parts: [.init(text: text)]))
        
        // Limit history to last 10 messages, and ensure it starts with a "user" role
        while conversationHistory.count > 10 || (conversationHistory.first?.role == "model") {
            conversationHistory.removeFirst()
        }
        
        // Define function declarations for tools
        let tools = [
            GeminiRequest.Tool(
                functionDeclarations: [
                    .init(
                        name: "changeScene",
                        description: "Altera a cena atual da transmissão.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [
                                "sceneName": .init(type: "STRING", description: "Nome exato da cena para a qual mudar (ex: Chat, Câmera Principal).")
                            ],
                            required: ["sceneName"]
                        )
                    ),
                    .init(
                        name: "muteMicrophone",
                        description: "Muta ou desmuta o áudio do microfone da stream.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [
                                "mute": .init(type: "BOOLEAN", description: "true para silenciar o áudio, false para ativar o áudio.")
                            ],
                            required: ["mute"]
                        )
                    ),
                    .init(
                        name: "toggleTorch",
                        description: "Liga ou desliga o flash/lanterna da câmera.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [
                                "on": .init(type: "BOOLEAN", description: "true para ligar a lanterna, false para desligar.")
                            ],
                            required: ["on"]
                        )
                    ),
                    .init(
                        name: "displayOverlayImage",
                        description: "Exibe uma imagem ou foto de uma URL na tela da transmissão.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [
                                "url": .init(type: "STRING", description: "A URL HTTP direta da imagem a ser carregada na tela."),
                                "durationSeconds": .init(type: "INTEGER", description: "Duração em segundos para manter a imagem visível (padrão: 10 segundos).")
                            ],
                            required: ["url"]
                        )
                    ),
                    .init(
                        name: "showOverlayText",
                        description: "Exibe uma caixa de texto ou alerta informativo sobreposto na tela.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [
                                "text": .init(type: "STRING", description: "A mensagem que aparecerá na tela do stream."),
                                "durationSeconds": .init(type: "INTEGER", description: "Duração em segundos para exibir o texto na tela (padrão: 8 segundos).")
                            ],
                            required: ["text"]
                        )
                    )
                ],
                googleSearch: nil
            ),
            GeminiRequest.Tool(
                functionDeclarations: nil,
                googleSearch: GeminiRequest.Tool.GoogleSearch()
            )
        ]
        
        let sysInstruction = systemInstruction.map {
            GeminiRequest.SystemInstruction(parts: [.init(text: $0)])
        } ?? GeminiRequest.SystemInstruction(parts: [.init(text: "Você é o Moblin AI, um assistente de voz extremamente útil, rápido e direto para streamers IRL mobile. Responda SEMPRE tentando executar ações via function calls quando fizer sentido. Use tom descontraído, mas profissional durante a live. Priorize comandos curtos e precisos.")])
        
        let requestBody = GeminiRequest(
            contents: conversationHistory,
            systemInstruction: sysInstruction,
            tools: tools
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        session.dataTask(with: request) { [weak self] data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "GeminiService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
                var actions: [GeminiAction] = []
                var textResponse: String? = nil
                
                if let candidate = response.candidates?.first, let content = candidate.content, let parts = content.parts {
                    for part in parts {
                        if let text = part.text {
                            textResponse = text
                        }
                        if let fc = part.functionCall {
                            let type = GeminiActionType(rawValue: fc.name) ?? .unknown
                            var params: [String: Any] = [:]
                            if let args = fc.args {
                                for (key, value) in args {
                                    params[key] = value.toAny()
                                }
                            }
                            actions.append(GeminiAction(type: type, parameters: params))
                        }
                    }
                    
                    // Save assistant response to history
                    if let self = self {
                        let assistantText = textResponse ?? "Executando ações solicitadas."
                        Task {
                            await self.appendModelResponse(text: assistantText)
                        }
                    }
                }
                
                completion(.success((actions, textResponse)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func appendModelResponse(text: String) {
        conversationHistory.append(ChatMessage(role: "model", parts: [.init(text: text)]))
    }
    
    func clearHistory() {
        conversationHistory.removeAll()
    }
}
