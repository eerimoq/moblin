//
//  WidgetImageUrlSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetImageUrlSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    
    var body: some View {
        Form {
            TextField("", text: Binding(get: {
                widget.image.url
            }, set: { value in
                widget.image.url = value.trim()
                model.store()
            }))
        }
        .navigationTitle("URL")
    }
}

struct WidgetImageUrlSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetImageUrlSettingsView(model: Model(), widget: SettingsWidget(name: ""))
    }
}
