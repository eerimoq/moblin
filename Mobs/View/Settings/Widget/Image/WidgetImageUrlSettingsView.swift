//
//  WidgetImageUrlSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct WidgetImageUrlSettingsView: View {
    @ObservedObject var model: Model
    @State private var url: String
    var widget: SettingsWidget
    
    init(model: Model, widget: SettingsWidget) {
        self.model = model
        self.widget = widget
        self.url = widget.image.url
    }
    
    var body: some View {
        Form {
            TextField("", text: $url)
                .onSubmit {
                    widget.image.url = url.trim()
                    model.store()
                }
        }
        .navigationTitle("URL")
    }
}
