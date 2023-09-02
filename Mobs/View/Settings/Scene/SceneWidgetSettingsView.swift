//
//  SceneWidgetSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct SceneWidgetSettingsView: View {
    @ObservedObject private var model: Model
    private var widget: SettingsSceneWidget
    private var name: String
    
    init(model: Model, widget: SettingsSceneWidget, name: String) {
        self.model = model
        self.widget = widget
        self.name = name
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: SceneWidgetXSettingsView(model: model, widget: widget)) {
                TextItemView(name: "X", value: "\(widget.x)")
            }
            NavigationLink(destination: SceneWidgetYSettingsView(model: model, widget: widget)) {
                TextItemView(name: "Y", value: "\(widget.y)")
            }
            NavigationLink(destination: SceneWidgetWSettingsView(model: model, widget: widget)) {
                TextItemView(name: "Width", value: "\(widget.w)")
            }
            NavigationLink(destination: SceneWidgetHSettingsView(model: model, widget: widget)) {
                TextItemView(name: "Height", value: "\(widget.h)")
            }
        }
        .navigationTitle("Widget")
    }
}
