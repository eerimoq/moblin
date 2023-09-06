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
    
    func submitUrl(value: String) {
        if makeRtmpUri(url: value) == "" {
            return
        }
        if makeRtmpStreamName(url: value) == "" {
            return
        }
        connection.rtmpUrl = value
        model.store()
        if connection.enabled {
            model.rtmpUrlChanged()
        }
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: TextEditView(title: "URL", value: connection.rtmpUrl, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: connection.rtmpUrl)
            }
        }
        .navigationTitle("RTMP")
    }
}
