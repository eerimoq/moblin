import SwiftUI

struct ConnectionSettingsView: View {
    private var connection: SettingsConnection
    @ObservedObject private var model: Model
    @State private var proto: String

    init(connection: SettingsConnection, model: Model) {
        self.connection = connection
        self.model = model
        self.proto = connection.proto
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
            NavigationLink(destination: ConnectionTwitchSettingsView(model: model, connection: connection)) {
                Text("Twitch")
            }
            NavigationLink(destination: ConnectionVideoSettingsView(model: model, connection: connection)) {
                Text("Video")
            }
            NavigationLink(destination: ConnectionRtmpSettingsView(model: model, connection: connection)) {
                Text("RTMP")
            }
            NavigationLink(destination: ConnectionSrtSettingsView(model: model, connection: connection)) {
                Text("SRT")
            }
            Section("Protocol") {
                Picker("", selection: $proto) {
                    ForEach(["RTMP", "SRT"], id: \.self) {
                        Text($0)
                    }
                }
                .onChange(of: proto) { proto in
                    connection.proto = proto
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Connection")
    }
}
