import SwiftUI

struct GeminiSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @State private var apiKeyText = ""
    
    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Enabled"), isOn: Binding(
                    get: { database.gemini.enabled },
                    set: { 
                        database.gemini.enabled = $0
                        model.sceneUpdated(updateRemoteScene: false)
                    }
                ))
                Toggle(String(localized: "Control Remote Streamer (macOS)"), isOn: Binding(
                    get: { database.gemini.remoteControl },
                    set: { 
                        database.gemini.remoteControl = $0
                        model.sceneUpdated(updateRemoteScene: false)
                    }
                ))
            }
            
            Section(header: Text(String(localized: "Model"))) {
                TextField(String(localized: "Model Name"), text: Binding(
                    get: { database.gemini.modelName },
                    set: {
                        database.gemini.modelName = $0
                        model.sceneUpdated(updateRemoteScene: false)
                    }
                ))
            }
            
            Section(
                header: Text(String(localized: "API Key")),
                footer: Text(String(localized: "Get your key from Google AI Studio (ai.google.dev)."))
            ) {
                SecureField(String(localized: "API Key"), text: $apiKeyText)
                    .onAppear {
                        apiKeyText = database.gemini.loadApiKey()
                    }
                    .onChange(of: apiKeyText) { newValue in
                        database.gemini.storeApiKey(key: newValue)
                    }
            }
            
            Section(
                header: Text(String(localized: "System Instructions")),
                footer: Text(String(localized: "Customize the AI's personality and instructions. Leave blank for default."))
            ) {
                TextEditor(text: Binding(
                    get: { database.gemini.systemInstruction },
                    set: {
                        database.gemini.systemInstruction = $0
                        model.sceneUpdated(updateRemoteScene: false)
                    }
                ))
                .frame(height: 120)
            }
            
            Section(
                footer: Text(String(localized: "Aviso de Privacidade: Ao ativar e utilizar o Gemini AI, seus comandos de voz e transcrições de texto serão enviados para a API do Google Gemini para processamento."))
            ) {}
        }
        .navigationTitle(String(localized: "Gemini AI"))
    }
}
