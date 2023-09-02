import SwiftUI

func getConnection(index: Int, model: Model) -> SettingsConnection {
    return model.settings.database.connections[index]
}

struct ConnectionSettingsView: View {
    private var index: Int
    @ObservedObject private var model: Model
    @State private var transport: String

    init(index: Int, model: Model) {
        self.index = index
        self.model = model
        self.transport = "RTMP"
    }
    
    var connection: SettingsConnection {
        get {
            model.settings.database.connections[index]
        }
    }

    var body: some View {
        Form {
            NavigationLink(destination: ConnectionNameSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(connection.name).foregroundColor(.gray)
                }
            }
            NavigationLink(destination: ConnectionRtmpSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("RTMP")
                }
            }
            NavigationLink(destination: ConnectionSrtSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("SRT")
                }
            }
            NavigationLink(destination: ConnectionTwitchSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("Twitch")
                }
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

struct ConnectionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSettingsView(index: 0, model: Model())
    }
}
