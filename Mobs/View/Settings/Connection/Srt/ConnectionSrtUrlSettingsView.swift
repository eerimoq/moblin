//
//  ConnectionSrtNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionSrtUrlSettingsView: View {
    @ObservedObject private var model: Model
    private var connection: SettingsConnection
    @State private var url: String
    
    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
        self.url = connection.srtUrl
    }
    
    var body: some View {
        Form {
            TextField("", text: $url)
                .onSubmit {
                    let srtUrl = url.trim()
                    if URL(string: srtUrl) == nil {
                        return
                    }
                    connection.srtUrl = srtUrl
                    model.store()
                    model.srtUrlChanged()
                }
        }
        .navigationTitle("URL")
    }
}

struct ConnectionSrtUrlSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSrtUrlSettingsView(model: Model(), connection: SettingsConnection(name: ""))
    }
}
