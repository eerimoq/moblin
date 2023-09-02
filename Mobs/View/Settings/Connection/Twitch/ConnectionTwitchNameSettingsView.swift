//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionTwitchChannelNameSettingsView: View {
    @ObservedObject private var model: Model
    @State private var channelName: String
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.channelName = connection.twitchChannelName
        self.connection = connection
    }
    
    var body: some View {
        Form {
            TextField("", text: $channelName)
                .onSubmit {
                    connection.twitchChannelName = channelName.trim()
                    model.store()
                    model.twitchChannelNameUpdated()
                }
        }
        .navigationTitle("Channel name")
    }
}

struct ConnectionTwitchChannelNameSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionTwitchSettingsView(model: Model(), connection: SettingsConnection(name: "Foo"))
    }
}
