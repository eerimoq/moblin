import Foundation

enum GeminiActionType: String {
    case changeScene
    case muteMicrophone
    case toggleTorch
    case displayOverlayImage
    case showOverlayText
    case displayYouTubeLive
    case removeYouTubeLive
    case searchWeb
    case unknown
}

struct GeminiAction {
    let type: GeminiActionType
    let parameters: [String: Any]
}

struct GeminiErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let code: Int
        let message: String
        let status: String
    }

    let error: ErrorDetail
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

    private func sanitizeHistory(_ history: [ChatMessage]) -> [ChatMessage] {
        var sanitized: [ChatMessage] = []
        for msg in history {
            if let last = sanitized.last {
                if last.role == msg.role {
                    // Combine consecutive messages of the same role
                    let combinedText = (last.parts.compactMap(\.text) + msg.parts.compactMap(\.text))
                        .joined(separator: "\n")
                    sanitized[sanitized.count - 1] = ChatMessage(
                        role: last.role,
                        parts: [.init(text: combinedText)]
                    )
                } else {
                    sanitized.append(msg)
                }
            } else {
                sanitized.append(msg)
            }
        }

        // Ensure the conversation starts with "user" role
        while !sanitized.isEmpty, sanitized.first?.role != "user" {
            sanitized.removeFirst()
        }

        return sanitized
    }

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
            case let .string(s): s
            case let .int(i): i
            case let .double(d): d
            case let .bool(b): b
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
            completion(.failure(NSError(
                domain: "GeminiService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "API Key is empty"]
            )))
            return
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(
                domain: "GeminiService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"]
            )))
            return
        }

        var request = URLRequest(url: url)
        logger.info("gemini-service: Calling model '\(modelName)'")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Append user prompt to history
        conversationHistory.append(ChatMessage(role: "user", parts: [.init(text: text)]))

        // Sanitize history to prevent consecutive user messages
        conversationHistory = sanitizeHistory(conversationHistory)

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
                                "sceneName": .init(
                                    type: "STRING",
                                    description: "Nome exato da cena para a qual mudar (ex: Chat, Câmera Principal)."
                                ),
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
                                "mute": .init(
                                    type: "BOOLEAN",
                                    description: "true para silenciar o áudio, false para ativar o áudio."
                                ),
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
                                "on": .init(
                                    type: "BOOLEAN",
                                    description: "true para ligar a lanterna, false para desligar."
                                ),
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
                                "url": .init(
                                    type: "STRING",
                                    description: "A URL HTTP direta da imagem a ser carregada na tela."
                                ),
                                "durationSeconds": .init(
                                    type: "INTEGER",
                                    description: "Duração em segundos para manter a imagem visível (padrão: 10 segundos)."
                                ),
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
                                "text": .init(
                                    type: "STRING",
                                    description: "A mensagem que aparecerá na tela do stream."
                                ),
                                "durationSeconds": .init(
                                    type: "INTEGER",
                                    description: "Duração em segundos para exibir o texto na tela (padrão: 8 segundos)."
                                ),
                            ],
                            required: ["text"]
                        )
                    ),
                    .init(
                        name: "displayYouTubeLive",
                        description: "Abre e exibe um vídeo/live do YouTube ou QUALQUER página da web (como mapas, previsão do tempo) como overlay na tela. Use para vídeos, streams ou páginas web normais encontradas na busca que não sejam imagens diretas.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [
                                "url": .init(
                                    type: "STRING",
                                    description: "URL completa do YouTube ou página da web (ex: https://www.youtube.com/watch?v=VIDEO_ID ou link do site/mapa)"
                                ),
                                "position": .init(
                                    type: "STRING",
                                    description: "Posição do overlay na tela (opções: top-left, top-right, bottom-left, bottom-right, center, fullscreen)"
                                ),
                                "width": .init(
                                    type: "INTEGER",
                                    description: "Largura em pixels (padrão 600)"
                                ),
                                "height": .init(
                                    type: "INTEGER",
                                    description: "Altura em pixels (padrão 400)"
                                ),
                                "opacity": .init(
                                    type: "NUMBER",
                                    description: "Opacidade de 0.0 a 1.0 (padrão 1.0)"
                                ),
                            ],
                            required: ["url"]
                        )
                    ),
                    .init(
                        name: "removeYouTubeLive",
                        description: "Remove ou fecha o vídeo/stream do YouTube que está atualmente exibido na tela.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [:],
                            required: []
                        )
                    ),
                    .init(
                        name: "searchWeb",
                        description: "Pesquisa na web por links de imagens, lives do YouTube ou informações gerais necessárias para atender ao usuário.",
                        parameters: .init(
                            type: "OBJECT",
                            properties: [
                                "query": .init(
                                    type: "STRING",
                                    description: "O termo a ser pesquisado (ex: 'gato fofo', 'live rio de janeiro youtube')."
                                ),
                            ],
                            required: ["query"]
                        )
                    ),
                ],
                googleSearch: nil
            ),
        ]

        let sysInstruction = systemInstruction.map {
            GeminiRequest.SystemInstruction(parts: [.init(text: $0)])
        } ?? GeminiRequest.SystemInstruction(parts: [.init(text: """
        Você é o Moblin AI, um assistente de voz autônomo com controle TOTAL da transmissão e interface. Responda SEMPRE tentando executar ações via function calls quando fizer sentido.
        REGRAS CRÍTICAS DE AUTONOMIA:
        1. Se o usuário pedir para colocar uma FOTO, IMAGEM, VÍDEO, LIVE ou informação e você NÃO tiver o link direto, você DEVE usar a ferramenta 'searchWeb' para pesquisar na web.
        2. Ao chamar 'searchWeb', o app fará a busca e trará os resultados no próximo turno da conversa. Com base nos links recebidos:
           - Se for um link direto de imagem (terminando em .jpg, .png, .gif, etc.), chame 'displayOverlayImage' com a URL.
           - Se os resultados forem páginas HTML normais (ex: sites de previsão de tempo, Wikipedia, mapas, sites de notícias) ou vídeos/lives do YouTube, chame 'displayYouTubeLive' com a URL (o aplicativo consegue carregar qualquer site no player/webview).
        3. Se o usuário pedir para colocar uma imagem de algo simples (ex: gato, cachorro) de forma muito rápida, você pode usar 'https://loremflickr.com/600/400/<termo_em_ingles>' (ex: 'https://loremflickr.com/600/400/cat') e passar como parâmetro 'url' na ferramenta 'displayOverlayImage' de imediato.
        4. Se o usuário pedir para procurar ou colocar uma live/vídeo do YouTube por termo de busca (ex: 'procura uma live de Balneário Camboriú'), você pode chamar 'displayYouTubeLive' passando no parâmetro 'url' a string 'youtube-search://<termo_de_busca>' (ex: 'youtube-search://Balneário Camboriú') para uma busca rápida nativa.
        5. Se pedir para remover/fechar o vídeo ou live, chame 'removeYouTubeLive'.
        6. Responda de forma natural em português brasileiro após executar a ação. Use tom descontraído e direto.
        """)])

        let requestBody = GeminiRequest(
            contents: conversationHistory,
            systemInstruction: sysInstruction,
            tools: tools
        )

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                logger.info("gemini-service: Request payload: \(jsonString)")
            }
            request.httpBody = jsonData
        } catch {
            logger.info("gemini-service: Failed to encode request body: \(error)")
            completion(.failure(error))
            return
        }

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                logger.info("gemini-service: URLSession error: \(error)")
                completion(.failure(error))
                return
            }

            guard let data else {
                logger.info("gemini-service: No data received")
                completion(.failure(NSError(
                    domain: "GeminiService",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "No data received"]
                )))
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                logger.info("gemini-service: Response payload: \(responseString)")
            }

            if let httpResponse = response as? HTTPURLResponse {
                logger.info("gemini-service: HTTP Response status code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let errorResponse = try? JSONDecoder().decode(GeminiErrorResponse.self, from: data) {
                        let errMsg = errorResponse.error.message
                        let status = errorResponse.error.status
                        let customError = NSError(
                            domain: "GeminiService",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "\(status): \(errMsg)"]
                        )
                        completion(.failure(customError))
                        return
                    } else {
                        let customError = NSError(
                            domain: "GeminiService",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP Error \(httpResponse.statusCode)"]
                        )
                        completion(.failure(customError))
                        return
                    }
                }
            }

            do {
                let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
                var actions: [GeminiAction] = []
                var textResponse: String? = nil

                if let candidate = response.candidates?.first, let content = candidate.content,
                   let parts = content.parts
                {
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
                    if let self {
                        let assistantText = textResponse ?? "Executando ações solicitadas."
                        Task {
                            await self.appendModelResponse(text: assistantText)
                        }
                    }
                }

                completion(.success((actions, textResponse)))
            } catch {
                logger.info("gemini-service: Decoding failed with error: \(error)")
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
