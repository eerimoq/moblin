import SwiftUI

struct VariableSettingsView: View {
    private var index: Int
    @ObservedObject var model: Model
    let types = ["Text", "HTTP", "Twitch PubSub", "Websocket"]
    
    init(index: Int, model: Model) {
        self.index = index
        self.model = model
    }
    
    func getType() -> String {
        self.model.settings.database.variables[self.index].type
    }
    
    var body: some View {
        Form {
            Section("Name") {
                TextField("", text: Binding(get: {
                    self.model.settings.database.variables[self.index].name
                }, set: { value in
                    self.model.settings.database.variables[self.index].name = value
                    self.model.settings.store()
                    self.model.numberOfVariables += 0
                }))
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    self.model.settings.database.variables[self.index].type
                }, set: { value in
                    self.model.settings.database.variables[self.index].type = value
                    self.model.settings.store()
                    self.model.numberOfVariables += 0
                })) {
                    ForEach(types, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if self.getType() == "Text" {
                Section("Value") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.variables[self.index].text.value
                    }, set: { value in
                        self.model.settings.database.variables[self.index].text.value = value
                        self.model.settings.store()
                    }))
                }
            } else if self.getType() == "HTTP" {
                Section("URL") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.variables[self.index].http.url
                    }, set: { value in
                        self.model.settings.database.variables[self.index].http.url = value
                        self.model.settings.store()
                    }))
                }
            } else if self.getType() == "Twitch PubSub" {
                Section("Pattern") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.variables[self.index].twitchPubSub.pattern
                    }, set: { value in
                        self.model.settings.database.variables[self.index].twitchPubSub.pattern = value
                        self.model.settings.store()
                    }))
                }
            } else if self.getType() == "Websocket" {
                Section("URL") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.variables[self.index].websocket.url
                    }, set: { value in
                        self.model.settings.database.variables[self.index].websocket.url = value
                        self.model.settings.store()
                    }))
                }
                Section("Pattern") {
                    TextField("", text: Binding(get: {
                        self.model.settings.database.variables[self.index].websocket.pattern
                    }, set: { value in
                        self.model.settings.database.variables[self.index].websocket.pattern = value
                        self.model.settings.store()
                    }))
                }
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
