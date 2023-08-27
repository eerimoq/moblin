import SwiftUI

struct VariableSettingsView: View {
    private var index: Int
    @ObservedObject var model: Model
    let types = ["Text", "HTTP", "Twitch PubSub", "Websocket"]

    init(index: Int, model: Model) {
        self.index = index
        self.model = model
    }

    var variable: SettingsVariable {
        get {
            model.settings.database.variables[self.index]
        }
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    variable.name
                }, set: { value in
                    variable.name = value
                    self.model.store()
                    self.model.numberOfVariables += 0
                }))
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    variable.type
                }, set: { value in
                    variable.type = value
                    self.model.store()
                    self.model.numberOfVariables += 0
                })) {
                    ForEach(types, id: \.self) {
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
                        variable.text.value = value
                        self.model.store()
                    }))
                }
            case "HTTP":
                Section("URL") {
                    TextField("", text: Binding(get: {
                        variable.http.url
                    }, set: { value in
                        variable.http.url = value
                        self.model.store()
                    }))
                }
            case "Twitch PubSub":
                Section("Pattern") {
                    TextField("", text: Binding(get: {
                        variable.twitchPubSub.pattern
                    }, set: { value in
                        variable.twitchPubSub.pattern = value
                        self.model.store()
                    }))
                }
            case "Websocket":
                Section("URL") {
                    TextField("", text: Binding(get: {
                        variable.websocket.url
                    }, set: { value in
                        variable.websocket.url = value
                        self.model.store()
                    }))
                }
                Section("Pattern") {
                    TextField("", text: Binding(get: {
                        variable.websocket.pattern
                    }, set: { value in
                        variable.websocket.pattern = value
                        self.model.store()
                    }))
                }
            default:
                EmptyView()
            }
        }
        .navigationTitle("Variable")
    }
}

struct VariableSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        VariableSettingsView(index: 0, model: Model())
    }
}
