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
                HStack {
                    Text("X")
                    Spacer()
                    Text("\(widget.x)").foregroundColor(.gray)
                }
            }
            NavigationLink(destination: SceneWidgetYSettingsView(model: model, widget: widget)) {
                HStack {
                    Text("Y")
                    Spacer()
                    Text("\(widget.y)").foregroundColor(.gray)
                }
            }
            NavigationLink(destination: SceneWidgetWSettingsView(model: model, widget: widget)) {
                HStack {
                    Text("Width")
                    Spacer()
                    Text("\(widget.w)").foregroundColor(.gray)
                }
            }
            NavigationLink(destination: SceneWidgetHSettingsView(model: model, widget: widget)) {
                HStack {
                    Text("Height")
                    Spacer()
                    Text("\(widget.h)").foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Widget")
    }
}

struct SceneWidgetSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SceneWidgetSettingsView(model: Model(), widget: SettingsSceneWidget(id: UUID()), name: "")
    }
}
