//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionTwitchChannelIdSettingsView: View {
    @ObservedObject private var model: Model
    @State private var channelId: String
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.channelId = connection.twitchChannelId
        self.connection = connection
    }
    
    var body: some View {
        Form {
            TextField("", text: $channelId)
                .onSubmit {
                    connection.twitchChannelId = channelId.trim()
                    model.store()
                    model.twitchChannelIdUpdated()
                }
        }
        .navigationTitle("Channel id")
    }
}

struct ConnectionTwitchChannelIdSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionTwitchChannelIdSettingsView(model: Model(), connection: SettingsConnection(name: "Foo"))
    }
}
