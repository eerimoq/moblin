//
//  ConnectionRtmpNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionRtmpUrlSettingsView: View {
    @ObservedObject private var model: Model
    private var connection: SettingsConnection
    @State private var url: String
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
        self.url = connection.rtmpUrl
    }
    
    var body: some View {
        Form {
            TextField("", text: $url)
                .onSubmit {
                    let rtmpUrl = url.trim()
                    if URL(string: rtmpUrl) == nil {
                        return
                    }
                    connection.rtmpUrl = rtmpUrl
                    model.store()
                    model.rtmpUrlChanged()
                }
        }
        .navigationTitle("URL")
    }
}

struct ConnectionRtmpUrlSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionRtmpUrlSettingsView(model: Model(), connection: SettingsConnection(name: ""))
    }
}
