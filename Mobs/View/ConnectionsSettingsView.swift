import SwiftUI

struct ConnectionsSettingsView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack {
            Form {
                ForEach(0..<self.model.numberOfConnections, id: \.self) { index in
                    NavigationLink(destination: ConnectionSettingsView(index: index, model: self.model)) {
                        Toggle(self.model.settings.database.connections[index].name, isOn: Binding(get: {
                            self.model.settings.database.connections[index].enabled
                        }, set: { value in
                            self.model.settings.database.connections[index].enabled = value
                            self.model.settings.store()
                        }))
                    }
                }.onDelete(perform: { offsets in
                    self.model.settings.database.connections.remove(atOffsets: offsets)
                    self.model.settings.store()
                    self.model.numberOfConnections -= 1
                })
                CreateButtonView(action: {
                    self.model.settings.database.connections.append(SettingsConnection(name: "My connection"))
                    self.model.settings.store()
                    self.model.numberOfConnections += 1
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
