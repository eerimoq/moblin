//
//  WidgetCameraSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetCameraSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    
    var body: some View {
        Section(widget.type) {
            NavigationLink(destination: WidgetCameraDirectionSettingsView(model: model, widget: widget)) {
                TextItemView(name: "Direction", value: widget.camera.direction)
            }
        }
    }
}
