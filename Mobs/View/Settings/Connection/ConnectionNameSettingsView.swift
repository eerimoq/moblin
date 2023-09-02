//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionNameSettingsView: View {
    @ObservedObject private var model: Model
    @State private var name: String
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.name = connection.name
        self.connection = connection
    }
    
    var body: some View {
        Form {
            TextField("", text: $name)
                .onSubmit {
                    connection.name = name.trim()
                    model.store()
                    model.numberOfConnections += 0
                }
        }
        .navigationTitle("Name")
    }
}

struct ConnectionNameSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionNameSettingsView(model: Model(), connection: SettingsConnection(name: "Foo"))
    }
}
