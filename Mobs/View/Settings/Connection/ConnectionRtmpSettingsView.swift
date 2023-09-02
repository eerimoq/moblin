//
//  ConnectionNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionRtmpSettingsView: View {
    @ObservedObject private var model: Model
    @State private var url: String
    private var connection: SettingsConnection
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.url = connection.rtmpUrl
        self.connection = connection
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
        .navigationTitle("RTMP URL")
    }
}

struct ConnectionRtmpSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionRtmpSettingsView(model: Model(), connection: SettingsConnection(name: "Foo"))
    }
}
