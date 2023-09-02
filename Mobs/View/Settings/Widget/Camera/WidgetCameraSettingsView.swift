//
//  WidgetCameraSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetCameraSettingsView: View {
    @ObservedObject var model: Model
    private var widget: SettingsWidget
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
    }
    
    var body: some View {
        Section(widget.type) {
            NavigationLink(destination: WidgetCameraDirectionSettingsView(model: model, widget: widget)) {
                HStack {
                    Text("Direction")
                    Spacer()
                    Text(widget.camera.direction).foregroundColor(.gray)
                }
            }
        }
    }
}

struct WidgetCameraSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetCameraSettingsView(model: Model(), widget: SettingsWidget(name: ""))
    }
}
