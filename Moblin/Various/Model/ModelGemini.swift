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
        let modelName = database.gemini.modelName.isEmpty ? "gemini-3.5-flash" : database.gemini.modelName
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
                        self.makeToast(title: String(localized: "Failed to connect to Gemini"))
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
            case .unknown:
                break
            }
        }
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
    
    func clearGeminiHistory() {
        Task {
            await geminiService.clearHistory()
        }
    }
}
