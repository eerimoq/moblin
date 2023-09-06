//
//  VideoSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-06.
//

import SwiftUI

struct ConnectionVideoSettingsView: View {
    @ObservedObject var model: Model
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
    }
    
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: ConnectionVideoResolutionSettingsView(model: model, connection: connection)) {
                    TextItemView(name: "Resolution", value: connection.resolution)
                }
                NavigationLink(destination: ConnectionVideoFpsSettingsView(model: model, connection: connection)) {
                    TextItemView(name: "FPS", value: "\(connection.fps)")
                }
            }
        }
        .navigationTitle("Video")
    }
}
