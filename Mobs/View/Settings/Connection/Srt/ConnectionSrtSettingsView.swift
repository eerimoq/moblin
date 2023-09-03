//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionSrtSettingsView: View {
    @ObservedObject private var model: Model
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
    }
    
    func submitUrl(value: String) {
        if URL(string: value) == nil {
            return
        }
        connection.srtUrl = value
        model.store()
        model.srtUrlChanged()
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: TextEditView(title: "URL", value: connection.srtUrl, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: connection.srtUrl)
            }
            Toggle("SRTLA", isOn: Binding(get: {
                connection.srtla
            }, set: { value in
                connection.srtla = value
                model.settings.store()
                model.srtlaChanged()
            }))
        }
        .navigationTitle("SRT")
    }
}
