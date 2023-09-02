//
//  WidgetTextFormatStringSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetTextFormatStringSettingsView: View {
    @ObservedObject var model: Model
    private var widget: SettingsWidget
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
    }
    
    var body: some View {
        Form {
            TextField("", text: Binding(get: {
                widget.text.formatString
            }, set: { value in
                widget.text.formatString = value.trim()
                model.store()
            }))
        }
        .navigationTitle("Format string")
    }
}

struct WidgetTextFormatStringSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetTextFormatStringSettingsView(model: Model(), widget: SettingsWidget(name: ""))
    }
}
