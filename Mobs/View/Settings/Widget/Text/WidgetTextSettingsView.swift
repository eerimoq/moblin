//
//  WidgetTextSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetTextSettingsView: View {
    @ObservedObject var model: Model
    private var widget: SettingsWidget
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
    }
    
    var body: some View {
        Section(widget.type) {
            NavigationLink(destination: WidgetTextFormatStringSettingsView(model: model, widget: widget)) {
                HStack {
                    Text("Format string")
                    Spacer()
                    Text(widget.text.formatString).foregroundColor(.gray)
                }
            }
        }
    }
}

struct WidgetTextSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetTextSettingsView(model: Model(), widget: SettingsWidget(name: ""))
    }
}
