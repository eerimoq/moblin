import SwiftUI

struct VariableSettingsView: View {
    var variable: SettingsVariable
    @ObservedObject var model: Model

    func submitName(name: String) {
        variable.name = name
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: variable.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: variable.name)
            }
            Section("Type") {
                Picker("", selection: Binding(get: {
                    variable.type.rawValue
                }, set: { value in
                    variable.type = SettingsVariableType(rawValue: value)!
                    model.store()
                    model.objectWillChange.send()
                })) {
                    ForEach(variableTypes, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            switch variable.type {
            case .text:
                Section("Value") {
                    TextField("", text: Binding(get: {
                        variable.text.value
                    }, set: { value in
                        variable.text.value = value.trim()
                        model.store()
                    }))
                }
            case .http:
                Section("URL") {
                    TextField("", text: Binding(get: {
                        variable.http.url
                    }, set: { value in
                        variable.http.url = value.trim()
                        model.store()
                    }))
                }
            case .twitchPubSub:
                Section("Pattern") {
                    TextField("", text: Binding(get: {
                        variable.twitchPubSub.pattern
                    }, set: { value in
                        variable.twitchPubSub.pattern = value.trim()
                        model.store()
                    }))
                }
            case .websocket:
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
            }
        }
        .navigationTitle("Variable")
    }
}
