import SwiftUI

struct GeminiSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @State private var apiKeyText = ""
    @State private var isCustomModel = false
    @State private var customModelName = ""

    private let standardModels = [
        "gemini-3.5-flash",
        "gemini-3.1-flash-lite",
        "gemini-3.1-pro-preview",
        "gemini-2.5-flash",
        "gemini-2.5-pro",
    ]

    private func getQuotaInfo(modelName: String) -> String {
        switch modelName {
        case "gemini-3.5-flash":
            String(
                localized: "Recomendado. Limites: 10 RPM (Requisições/Minuto) / 10.000 RPD (por dia) no plano gratuito. Resposta ultrarrápida, ideal para transmissões."
            )
        case "gemini-3.1-flash-lite":
            String(
                localized: "Mais leve. Limites: 15 RPM / 1.500 RPD no plano gratuito. Menor latência para comandos básicos."
            )
        case "gemini-3.1-pro-preview":
            String(
                localized: "Alta inteligência. Limites: 2 RPM / 50 RPD no plano gratuito. Perfeito para instruções complexas, mas com maior latência."
            )
        case "gemini-2.5-flash":
            String(localized: "Modelo balanceado anterior. Limites: 15 RPM / 1.500 RPD no plano gratuito.")
        case "gemini-2.5-pro":
            String(localized: "Modelo avançado anterior. Limites: 2 RPM / 50 RPD no plano gratuito.")
        default:
            String(
                localized: "Modelo personalizado. Os limites de cota dependem do modelo configurado e de seu plano (Pay-as-you-go ou Gratuito) no Google AI Studio."
            )
        }
    }

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

            Section(
                header: Text(String(localized: "Model")),
                footer: Text(getQuotaInfo(modelName: database.gemini.modelName))
            ) {
                Picker(String(localized: "Model Name"), selection: Binding(
                    get: {
                        if standardModels.contains(database.gemini.modelName) {
                            database.gemini.modelName
                        } else if database.gemini.modelName.isEmpty {
                            "gemini-3.5-flash"
                        } else {
                            "custom"
                        }
                    },
                    set: { newValue in
                        if newValue == "custom" {
                            isCustomModel = true
                            database.gemini.modelName = customModelName
                                .isEmpty ? "gemini-3.5-flash" : customModelName
                        } else {
                            isCustomModel = false
                            database.gemini.modelName = newValue
                        }
                        model.sceneUpdated(updateRemoteScene: false)
                    }
                )) {
                    ForEach(standardModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                    Text(String(localized: "Custom...")).tag("custom")
                }

                if isCustomModel {
                    TextField(String(localized: "Custom Model Name"), text: Binding(
                        get: { customModelName },
                        set: {
                            customModelName = $0
                            database.gemini.modelName = $0
                            model.sceneUpdated(updateRemoteScene: false)
                        }
                    ))
                }
            }

            Section(
                header: Text(String(localized: "API Key")),
                footer: Text(String(localized: "Get your key from Google AI Studio (ai.google.dev)."))
            ) {
                SecureField(String(localized: "API Key"), text: $apiKeyText)
                    .onAppear {
                        apiKeyText = database.gemini.loadApiKey()
                        let currentModel = database.gemini.modelName
                        if !standardModels.contains(currentModel), !currentModel.isEmpty {
                            isCustomModel = true
                            customModelName = currentModel
                        } else {
                            isCustomModel = false
                            customModelName = ""
                        }
                    }
                    .onChange(of: apiKeyText) { newValue in
                        database.gemini.storeApiKey(key: newValue)
                        model.storeSettings()
                    }
            }

            Section(
                header: Text(String(localized: "System Instructions")),
                footer: Text(
                    String(
                        localized: "Customize the AI's personality and instructions. Leave blank for default."
                    )
                )
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
                footer: Text(
                    String(
                        localized: "Aviso de Privacidade: Ao ativar e utilizar o Gemini AI, seus comandos de voz e transcrições de texto serão enviados para a API do Google Gemini para processamento."
                    )
                )
            ) {}
        }
        .navigationTitle(String(localized: "Gemini AI"))
    }
}
