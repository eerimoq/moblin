import SwiftUI

struct ConnectionsSettingsView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        Form {
            ForEach(self.model.connections, id: \.self) { connection in
                NavigationLink(destination: ConnectionSettingsView(name: connection)) {
                    Toggle(connection, isOn: $model.isConnectionOn)
                }
            }.onDelete(perform: { offsets in
                print("delete connection")
            })
            CreateButtonView()
        }
        .navigationTitle("Connections")
    }
}

struct ConnectionsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsSettingsView(model: Model())
    }
}
