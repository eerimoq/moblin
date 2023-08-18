import SwiftUI

struct VariableSettingsView: View {
    @ObservedObject var model: Model
    let kinds = ["Text", "HTTP", "Twitch PubSub", "Websocket"]
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: $model.variableName)
            }
            Section("Kind") {
                Picker("", selection: $model.variableSelectedKind) {
                    ForEach(kinds, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if self.model.variableSelectedKind == "Text" {
                Section("Value") {
                    TextField("", text: $model.textVariableValue)
                }
            } else if self.model.variableSelectedKind == "HTTP" {
                Section("URL") {
                    TextField("", text: $model.httpUrlVariableValue)
                }
            } else if self.model.variableSelectedKind == "Twitch PubSub" {
                Section("Pattern") {
                    TextField("", text: $model.twitchPubSubVariableValue)
                }
            } else if self.model.variableSelectedKind == "Websocket" {
                Section("URL") {
                    TextField("", text: $model.websocketUrlVariableValue)
                }
                Section("Pattern") {
                    TextField("", text: $model.websocketPatternVariableValue)
                }
            }
        }
        .navigationTitle("Variable")
    }
}

struct VariableSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        VariableSettingsView(model: Model())
    }
}
