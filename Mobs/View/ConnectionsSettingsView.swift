import SwiftUI

struct ConnectionsSettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.settings.database
        }
    }

    var body: some View {
        VStack {
            Form {
                ForEach(0..<model.numberOfConnections, id: \.self) { index in
                    NavigationLink(destination: ConnectionSettingsView(index: index, model: model)) {
                        Toggle(database.connections[index].name, isOn: Binding(get: {
                            database.connections[index].enabled
                        }, set: { value in
                            database.connections[index].enabled = value
                            model.store()
                        }))
                    }
                }.onDelete(perform: { offsets in
                    database.connections.remove(atOffsets: offsets)
                    model.store()
                    model.numberOfConnections -= 1
                })
                CreateButtonView(action: {
                    database.connections.append(SettingsConnection(name: "My connection"))
                    model.store()
                    model.numberOfConnections += 1
                })
            }
        }
        .navigationTitle("Connections")
    }
}

struct ConnectionsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsSettingsView(model: Model())
    }
}
