//
//  WidgetTextFormatStringSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetTextFormatStringSettingsView: View {
    @ObservedObject var model: Model
    @State private var formatString: String
    var widget: SettingsWidget
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        self.formatString = widget.text.formatString
    }
    
    var body: some View {
        Form {
            TextField("", text: $formatString)
                .onSubmit {
                    widget.text.formatString = formatString.trim()
                    model.store()
                }
        }
        .navigationTitle("Format string")
    }
}

struct WidgetTextFormatStringSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetTextFormatStringSettingsView(model: Model(), widget: SettingsWidget(name: ""))
    }
}
