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
                TextItemView(name: "URL", value: connection.rtmpUrl)
            }
        }
        .navigationTitle("RTMP")
    }
}
