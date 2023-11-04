//
//  ScenesButtonsSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-03.
//

import SwiftUI

struct ButtonsSettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Form {}
            .navigationTitle("Buttons")
    }
}
