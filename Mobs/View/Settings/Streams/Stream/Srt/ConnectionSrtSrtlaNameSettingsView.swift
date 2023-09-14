//
//  ConnectionSrtSrtlaNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct ConnectionSrtSrtlaSettingsView: View {
    @ObservedObject private var model: Model
    private var connection: SettingsConnection

    init(model: Model, connection: SettingsConnection) {
        self.model = model
        self.connection = connection
    }

    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct ConnectionSrtSrtlaSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionSrtSrtlaSettingsView(model: Model(), connection: SettingsConnection(name: ""))
    }
}
