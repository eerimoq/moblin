//
//  WidgetCameraDirectionSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

var directions = ["Back", "Front"]

struct WidgetCameraDirectionSettingsView: View {
    @ObservedObject var model: Model
    private var widget: SettingsWidget
    @State private var selection: String
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        self.selection = widget.camera.direction
    }
    
    var body: some View {
        Form {
            Picker("", selection: $selection) {
                ForEach(directions, id: \.self) { direction in
                    Text(direction)
                }
            }
            .onChange(of: selection) { direction in
                widget.camera.direction = direction.trim()
                model.store()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Direction")
    }
}
