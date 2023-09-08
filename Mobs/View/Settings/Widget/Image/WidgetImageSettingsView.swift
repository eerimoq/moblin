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
    
    func submitUrl(value: String) {
        widget.image.url = value
        model.store()
    }
    
    var body: some View {
        Section(widget.type) {
            NavigationLink(destination: TextEditView(title: "URL", value: widget.image.url, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: widget.image.url)
            }
        }
    }
}
