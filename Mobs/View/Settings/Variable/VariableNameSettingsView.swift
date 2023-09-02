//
//  VariableNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct VariableNameSettingsView: View {
    @ObservedObject private var model: Model
    @State private var name: String
    private var variable: SettingsVariable
    
    init(model: Model, variable: SettingsVariable) {
        self.model = model
        self.name = variable.name
        self.variable = variable
    }
    
    var body: some View {
        Form {
            TextField("", text: Binding(get: {
                variable.name
            }, set: { value in
                variable.name = value.trim()
                model.store()
                model.numberOfVariables += 0
            }))
        }
        .navigationTitle("Name")
    }
}
