import Foundation
import UIKit

extension Model {
    func toggleGeminiListening() {
        if isGeminiListening {
            stopGeminiListening()
        } else {
            startGeminiListening()
        }
    }
    
    func startGeminiListening() {
        guard database.gemini.enabled else {
            makeToast(title: String(localized: "Gemini is not enabled in settings"))
            return
        }
        
        let apiKey = database.gemini.loadApiKey()
        guard !apiKey.isEmpty else {
            makeToast(title: String(localized: "Gemini API Key is not set"))
            return
        }
        
        isGeminiListening = true
        geminiSpeechText = String(localized: "Listening...")
        setQuickButton(type: .gemini, isOn: true)
        updateQuickButtonStates()
        
        AudioUnit.onAudioSample = { [weak self] sampleBuffer in
            self?.voiceRecognizer.appendSampleBuffer(sampleBuffer)
        }
        
        voiceRecognizer.startRecording(
            onTextUpdated: { [weak self] text in
                DispatchQueue.main.async {
                    self?.geminiSpeechText = text
                }
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let text):
                    if !text.isEmpty {
                        self.sendToGemini(text: text)
                    } else {
                        self.stopGeminiListening()
                    }
                case .failure(let error):
                    logger.info("gemini-voice: Failed to transcribe: \(error)")
                    self.makeToast(title: String(localized: "Transcription failed"))
                    self.stopGeminiListening()
                }
            }
        )
    }
    
    func stopGeminiListening() {
        guard isGeminiListening else { return }
        isGeminiListening = false
        AudioUnit.onAudioSample = nil
        voiceRecognizer.stopRecording()
        setQuickButton(type: .gemini, isOn: false)
        updateQuickButtonStates()
    }
    
    func sendToGemini(text: String) {
        geminiSpeechText = String(localized: "Processing...")
        let apiKey = database.gemini.loadApiKey()
        var modelName = database.gemini.modelName.isEmpty ? "gemini-3.5-flash" : database.gemini.modelName
        if modelName == "gemini-2.0-flash" {
            modelName = "gemini-3.5-flash"
        }
        let sysInstruction = database.gemini.systemInstruction.isEmpty ? nil : database.gemini.systemInstruction
        
        Task {
            await geminiService.executeCommand(
                text: text,
                apiKey: apiKey,
                modelName: modelName,
                systemInstruction: sysInstruction
            ) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.stopGeminiListening()
                    
                    switch result {
                    case .success(let (actions, textResponse)):
                        if let textResponse = textResponse {
                            self.makeToast(title: textResponse)
                        }
                        self.executeGeminiActions(actions)
                    case .failure(let error):
                        logger.info("gemini-service: API call failed: \(error)")
                        self.makeToast(title: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func executeGeminiActions(_ actions: [GeminiAction]) {
        let isRemote = database.gemini.remoteControl
        
        if isRemote && !isRemoteControlAssistantConnected() {
            makeToast(title: String(localized: "Remote streamer is not connected"))
            return
        }
        
        for action in actions {
            switch action.type {
            case .changeScene:
                if let sceneName = action.parameters["sceneName"] as? String {
                    if isRemote {
                        if let remoteScene = remoteControl.settings?.scenes.first(where: { $0.name.lowercased() == sceneName.lowercased() }) {
                            remoteControlAssistantSetScene(id: remoteScene.id)
                            makeToast(title: String(localized: "Sent: Change scene to \(sceneName)"))
                        } else {
                            makeToast(title: String(localized: "Remote scene '\(sceneName)' not found"))
                        }
                    } else {
                        if let scene = database.scenes.first(where: { $0.name == sceneName }) {
                            selectScene(id: scene.id)
                            makeToast(title: String(localized: "Scene changed to \(sceneName)"))
                        } else {
                            makeToast(title: String(localized: "Scene '\(sceneName)' not found"))
                        }
                    }
                }
            case .muteMicrophone:
                if let mute = action.parameters["mute"] as? Bool {
                    if isRemote {
                        remoteControlAssistantSetMute(on: mute)
                        let status = mute ? String(localized: "Sent: Mute remote mic") : String(localized: "Sent: Unmute remote mic")
                        makeToast(title: status)
                    } else {
                        setMuted(value: mute)
                        let status = mute ? String(localized: "Microphone muted") : String(localized: "Microphone unmuted")
                        makeToast(title: status)
                    }
                }
            case .toggleTorch:
                if let on = action.parameters["on"] as? Bool {
                    if isRemote {
                        remoteControlAssistant?.setTorch(on: on) {
                            let status = on ? String(localized: "Sent: Turn remote torch on") : String(localized: "Sent: Turn remote torch off")
                            self.makeToast(title: status)
                        }
                    } else {
                        if streamOverlay.isTorchOn != on {
                            toggleTorch()
                        }
                        let status = on ? String(localized: "Torch turned on") : String(localized: "Torch turned off")
                        makeToast(title: status)
                    }
                }
            case .displayOverlayImage:
                if let url = action.parameters["url"] as? String {
                    let duration = action.parameters["durationSeconds"] as? Int ?? 10
                    displayGeminiImageOverlay(url: url, duration: duration)
                }
            case .showOverlayText:
                if let text = action.parameters["text"] as? String {
                    let duration = action.parameters["durationSeconds"] as? Int ?? 8
                    displayGeminiTextOverlay(text: text, duration: duration)
                }
            case .displayYouTubeLive:
                if let url = action.parameters["url"] as? String {
                    let position = action.parameters["position"] as? String ?? "center"
                    let width = action.parameters["width"] as? Int ?? 600
                    let height = action.parameters["height"] as? Int ?? 400
                    let opacity = action.parameters["opacity"] as? Double ?? 1.0
                    
                    if url.hasPrefix("youtube-search://") {
                        let query = url.replacingOccurrences(of: "youtube-search://", with: "")
                        makeToast(title: String(localized: "Buscando live de \(query)..."))
                        searchYouTubeLive(query: query) { [weak self] foundUrl in
                            DispatchQueue.main.async {
                                if let foundUrl = foundUrl {
                                    self?.geminiOverlayYouTubeURL = foundUrl
                                    self?.geminiOverlayYouTubePosition = position
                                    self?.geminiOverlayYouTubeWidth = width
                                    self?.geminiOverlayYouTubeHeight = height
                                    self?.geminiOverlayYouTubeOpacity = opacity
                                    self?.makeToast(title: String(localized: "Live carregada!"))
                                } else {
                                    self?.makeToast(title: String(localized: "Nenhuma live encontrada para \(query)"))
                                }
                            }
                        }
                    } else {
                        geminiOverlayYouTubeURL = url
                        geminiOverlayYouTubePosition = position
                        geminiOverlayYouTubeWidth = width
                        geminiOverlayYouTubeHeight = height
                        geminiOverlayYouTubeOpacity = opacity
                        makeToast(title: String(localized: "Abrindo overlay do YouTube..."))
                    }
                }
            case .removeYouTubeLive:
                geminiOverlayYouTubeURL = nil
                makeToast(title: String(localized: "Removendo overlay do YouTube"))
            case .searchWeb:
                if let query = action.parameters["query"] as? String {
                    makeToast(title: String(localized: "Pesquisando na web por \(query)..."))
                    performWebSearch(query: query) { [weak self] results in
                        guard let self = self else { return }
                        var responseText = "Resultados da pesquisa na web para '\(query)':\n"
                        if results.isEmpty {
                            responseText += "Nenhum resultado encontrado."
                        } else {
                            for (index, res) in results.enumerated() {
                                if let title = res["title"], let url = res["url"] {
                                    responseText += "\(index + 1). \(title) - URL: \(url)\n"
                                }
                            }
                        }
                        responseText += "\nCom base nestes resultados de pesquisa, complete a solicitação do usuário utilizando a ferramenta apropriada (ex: se for uma imagem, chame displayOverlayImage com um link direto; se for uma live do YouTube, chame displayYouTubeLive com o link)."
                        
                        DispatchQueue.main.async {
                            self.sendToGeminiSilent(resultsText: responseText)
                        }
                    }
                }
            case .unknown:
                break
            }
        }
    }
    
    private func searchYouTubeLive(query: String, completion: @escaping (String?) -> Void) {
        let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.youtube.com/results?search_query=\(escapedQuery)+live&sp=EgJAAQ%253D%253D"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            if let html = String(data: data, encoding: .utf8) {
                let pattern = "/(?:watch\\?v=|live/|shorts/)([a-zA-Z0-9_-]{11})"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
                    if let match = regex.firstMatch(in: html, options: [], range: nsRange) {
                        if let range = Range(match.range(at: 1), in: html) {
                            let videoId = String(html[range])
                            completion("https://www.youtube.com/watch?v=\(videoId)")
                            return
                        }
                    }
                }
            }
            completion(nil)
        }.resume()
    }
    
    private func displayGeminiImageOverlay(url: String, duration: Int) {
        geminiOverlayImageURL = url
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) { [weak self] in
            if self?.geminiOverlayImageURL == url {
                self?.geminiOverlayImageURL = nil
            }
        }
    }
    
    private func displayGeminiTextOverlay(text: String, duration: Int) {
        geminiOverlayText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(duration)) { [weak self] in
            if self?.geminiOverlayText == text {
                self?.geminiOverlayText = nil
            }
        }
    }
    
    func sendToGeminiSilent(resultsText: String) {
        let apiKey = database.gemini.loadApiKey()
        var modelName = database.gemini.modelName.isEmpty ? "gemini-3.5-flash" : database.gemini.modelName
        if modelName == "gemini-2.0-flash" {
            modelName = "gemini-3.5-flash"
        }
        let sysInstruction = database.gemini.systemInstruction.isEmpty ? nil : database.gemini.systemInstruction
        
        Task {
            await geminiService.executeCommand(
                text: resultsText,
                apiKey: apiKey,
                modelName: modelName,
                systemInstruction: sysInstruction
            ) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let (actions, textResponse)):
                        if let textResponse = textResponse {
                            self.makeToast(title: textResponse)
                        }
                        self.executeGeminiActions(actions)
                    case .failure(let error):
                        logger.info("gemini-service: Silent API call failed: \(error)")
                        self.makeToast(title: String(localized: "Erro silencioso: \(error.localizedDescription)"))
                    }
                }
            }
        }
    }
    
    private func performWebSearch(query: String, completion: @escaping ([[String: String]]) -> Void) {
        let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://html.duckduckgo.com/html/?q=\(escapedQuery)"
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion([])
                return
            }
            
            var results: [[String: String]] = []
            if let html = String(data: data, encoding: .utf8) {
                let pattern = "<a class=\"result__url\" href=\"([^\"]+)\"[^>]*>(.*?)</a>"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                    let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
                    let matches = regex.matches(in: html, options: [], range: nsRange)
                    
                    for match in matches.prefix(5) {
                        if let urlRange = Range(match.range(at: 1), in: html),
                           let titleRange = Range(match.range(at: 2), in: html) {
                            let rawUrl = String(html[urlRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            var finalUrl = rawUrl
                            if rawUrl.contains("uddg=") {
                                if let queryItems = URLComponents(string: "https://html.duckduckgo.com" + rawUrl)?.queryItems,
                                   let uddgValue = queryItems.first(where: { $0.name == "uddg" })?.value {
                                    finalUrl = uddgValue
                                }
                            }
                            
                            var title = String(html[titleRange])
                                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            title = title.replacingOccurrences(of: "&amp;", with: "&")
                                .replacingOccurrences(of: "&quot;", with: "\"")
                                .replacingOccurrences(of: "&#39;", with: "'")
                                .replacingOccurrences(of: "&lt;", with: "<")
                                .replacingOccurrences(of: "&gt;", with: ">")
                            
                            if !finalUrl.contains("duckduckgo.com") && finalUrl.hasPrefix("http") {
                                results.append(["title": title, "url": finalUrl])
                            }
                        }
                    }
                }
            }
            completion(results)
        }.resume()
    }
    
    func clearGeminiHistory() {
        Task {
            await geminiService.clearHistory()
        }
    }
}
