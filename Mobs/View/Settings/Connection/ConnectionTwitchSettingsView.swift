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
                HStack {
                    Text("Channel name")
                    Spacer()
                    Text(connection.twitchChannelName).foregroundColor(.gray)
                }
            }
            NavigationLink(destination: ConnectionTwitchChannelIdSettingsView(model: model, connection: connection)) {
                HStack {
                    Text("Channel id")
                    Spacer()
                    Text(connection.twitchChannelId).foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Twitch")
    }
}

struct ConnectionTwitchSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionTwitchSettingsView(model: Model(), connection: SettingsConnection(name: "Foo"))
    }
}
