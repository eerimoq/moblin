import SwiftUI

struct ConnectionSettingsView: View {
    private var connection: SettingsConnection
    @ObservedObject private var model: Model
    @State private var transport: String

    init(connection: SettingsConnection, model: Model) {
        self.connection = connection
        self.model = model
        self.transport = "RTMP"
    }
    
    func submitName(name: String) {
        connection.name = name
        model.store()
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(name: connection.name, onSubmit: submitName)) {
                TextItemView(name: "Name", value: connection.name)
            }
            NavigationLink(destination: ConnectionRtmpSettingsView(model: model, connection: connection)) {
                Text("RTMP")
            }
            NavigationLink(destination: ConnectionSrtSettingsView(model: model, connection: connection)) {
                Text("SRT")
            }
            NavigationLink(destination: ConnectionTwitchSettingsView(model: model, connection: connection)) {
                Text("Twitch")
            }
            Section("Protocol") {
                Picker("", selection: $transport) {
                    ForEach(["RTMP", "SRT"], id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Connection")
    }
}
