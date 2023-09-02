//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionTwitchSettingsView: View {
    @ObservedObject private var model: Model
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: ConnectionTwitchChannelNameSettingsView(model: model, connection: connection)) {
                TextItemView(name: "Channel name", value: connection.twitchChannelName)
            }
            NavigationLink(destination: ConnectionTwitchChannelIdSettingsView(model: model, connection: connection)) {
                TextItemView(name: "Channel id", value: connection.twitchChannelId)
            }
        }
        .navigationTitle("Twitch")
    }
}
