//
//  WidgetImageSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetImageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    
    var body: some View {
        Section(widget.type) {
            NavigationLink(destination: WidgetImageUrlSettingsView(model: model, widget: widget)) {
                TextItemView(name: "URL", value: widget.image.url)
            }
        }
    }
}

struct WidgetImageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetImageSettingsView(model: Model(), widget: SettingsWidget(name: ""))
    }
}
