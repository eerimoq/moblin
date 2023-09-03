import SwiftUI

struct VariableSettingsView: View {
    var index: Int
    @ObservedObject var model: Model

    var variable: SettingsVariable {
        get {
            model.settings.database.variables[index]
        }
    }

    func submitName(name: String) {
        variable.name = name.trim()
        model.store()
        model.numberOfVariables += 0
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(name: variable.name, onSubmit: submitName)) {
                TextItemView(name: "Name", value: variable.name)
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    variable.type
                }, set: { value in
                    variable.type = value.trim()
                    model.store()
                    model.numberOfVariables += 0
                })) {
                    ForEach(variableTypes, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            switch variable.type {
            case "Text":
                Section("Value") {
                    TextField("", text: Binding(get: {
                        variable.text.value
                    }, set: { value in
                        variable.text.value = value.trim()
                        model.store()
                    }))
                }
            case "HTTP":
                Section("URL") {
                    TextField("", text: Binding(get: {
                        variable.http.url
                    }, set: { value in
                        variable.http.url = value.trim()
                        model.store()
                    }))
                }
            case "Twitch PubSub":
                Section("Pattern") {
                    TextField("", text: Binding(get: {
                        variable.twitchPubSub.pattern
                    }, set: { value in
                        variable.twitchPubSub.pattern = value.trim()
                        model.store()
                    }))
                }
            case "Websocket":
                Section("URL") {
                    TextField("", text: Binding(get: {
                        variable.websocket.url
                    }, set: { value in
                        variable.websocket.url = value.trim()
                        model.store()
                    }))
                }
                Section("Pattern") {
                    TextField("", text: Binding(get: {
                        variable.websocket.pattern
                    }, set: { value in
                        variable.websocket.pattern = value.trim()
                        model.store()
                    }))
                }
            default:
                EmptyView()
            }
        }
        .navigationTitle("Variable")
    }
}
