//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionRtmpSettingsView: View {
    @ObservedObject private var model: Model
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: ConnectionRtmpUrlSettingsView(model: model, connection: connection)) {
                Text("URL")
            }
        }
        .navigationTitle("RTMP")
    }
}

struct ConnectionRtmpSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionRtmpSettingsView(model: Model(), connection: SettingsConnection(name: "Foo"))
    }
}
