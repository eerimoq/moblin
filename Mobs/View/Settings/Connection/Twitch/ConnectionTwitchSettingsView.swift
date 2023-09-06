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
    
    func submitChannelName(value: String) {
        connection.twitchChannelName = value
        model.store()
        if connection.enabled {
            model.twitchChannelNameUpdated()
        }
    }
    
    func submitChannelId(value: String) {
        connection.twitchChannelId = value
        model.store()
        if connection.enabled {
            model.twitchChannelIdUpdated()
        }
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: TextEditView(title: "Channel name", value: connection.twitchChannelName, onSubmit: submitChannelName)) {
                TextItemView(name: "Channel name", value: connection.twitchChannelName)
            }
            NavigationLink(destination: TextEditView(title: "Channel id", value: connection.twitchChannelId, onSubmit: submitChannelId)) {
                TextItemView(name: "Channel id", value: connection.twitchChannelId)
            }
        }
        .navigationTitle("Twitch")
    }
}
