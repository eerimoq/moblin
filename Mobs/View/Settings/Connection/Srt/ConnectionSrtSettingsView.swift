//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionSrtSettingsView: View {
    @ObservedObject private var model: Model
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: ConnectionSrtUrlSettingsView(model: model, connection: connection)) {
                TextItemView(name: "URL", value: connection.srtUrl)
            }
            Toggle("SRTLA", isOn: Binding(get: {
                connection.srtla
            }, set: { value in
                connection.srtla = value
                model.settings.store()
                model.srtlaChanged()
            }))
        }
        .navigationTitle("SRT")
    }
}

struct ConnectionSrtSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSrtSettingsView(model: Model(), connection: SettingsConnection(name: "Foo"))
    }
}
