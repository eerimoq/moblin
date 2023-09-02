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
    @State private var selection = 0
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        self.selection = directions.firstIndex(of: widget.camera.direction) ?? 0
    }
    
    var body: some View {
        Form {
            Picker("", selection: $selection) {
                ForEach(0..<2, id: \.self) { tag in
                    Text(directions[tag]).tag(tag)
                }
            }
            .onChange(of: selection) { tag in
                widget.camera.direction = directions[tag].trim()
                model.store()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle("Direction")
    }
}

struct WidgetCameraDirectionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetCameraDirectionSettingsView(model: Model(), widget: SettingsWidget(name: ""))
    }
}
