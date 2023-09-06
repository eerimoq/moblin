//
//  ButtonSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-04.
//

import SwiftUI

var fpss = [15, 30, 60]

struct ConnectionVideoFpsSettingsView: View {
    @ObservedObject var model: Model
    private var connection: SettingsConnection
    @State private var selection: Int
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
        self.selection = connection.fps
    }
    
    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(fpss, id: \.self) { fps in
                        Text("\(fps)")
                    }
                }
                .onChange(of: selection) { fps in
                    connection.fps = fps
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
