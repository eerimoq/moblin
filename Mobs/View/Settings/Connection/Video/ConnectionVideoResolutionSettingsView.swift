//
//  ButtonSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-04.
//

import SwiftUI

var resolutions = ["1920x1080", "1280x720"]

struct ConnectionVideoResolutionSettingsView: View {
    @ObservedObject var model: Model
    var connection: SettingsConnection
    @State private var selection: String
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
        self.selection = model.streamResolution
    }
    
    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(resolutions, id: \.self) { resolution in
                        Text(resolution)
                    }
                }
                .onChange(of: selection) { resolution in
                    connection.resolution = resolution
                    model.store()
                    if connection.enabled {
                        model.reloadConnection()
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Resolution")
    }
}
