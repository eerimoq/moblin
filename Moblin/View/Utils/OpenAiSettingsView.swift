import SwiftUI

struct OpenAiSettingsView: View {
    @ObservedObject var ai: SettingsOpenAi

    var body: some View {
        Section {
            TextEditNavigationView(title: String(localized: "Base URL"),
                                   value: ai.baseUrl,
                                   onChange: isValidHttpUrl,
                                   onSubmit: { ai.baseUrl = $0 })
            TextEditNavigationView(title: String(localized: "API key"),
                                   value: ai.apiKey,
                                   onSubmit: { ai.apiKey = $0 },
                                   sensitive: true)
            TextEditNavigationView(title: String(localized: "Model"),
                                   value: ai.model,
                                   onSubmit: { ai.model = $0 })
            MultiLineTextFieldNavigationView(title: String(localized: "Personality"),
                                             value: ai.personality,
                                             onSubmit: { ai.personality = $0 })
        } header: {
            Text("OpenAI compatible service")
        }
    }
}
