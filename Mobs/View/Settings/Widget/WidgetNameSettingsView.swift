//
//  widgetNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetNameSettingsView: View {
    @ObservedObject private var model: Model
    @State private var name: String
    private var widget: SettingsWidget
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.name = widget.name
        self.widget = widget
    }
    
    var body: some View {
        Form {
            TextField("", text: Binding(get: {
                widget.name
            }, set: { value in
                widget.name = value.trim()
                model.store()
                model.numberOfWidgets += 0
            }))
        }
        .navigationTitle("Name")
    }
}

struct WidgetNameSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetNameSettingsView(model: Model(), widget: SettingsWidget(name: "Foo"))
    }
}
