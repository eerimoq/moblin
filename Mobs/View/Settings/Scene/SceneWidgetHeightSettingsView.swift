//
//  SceneWidgetXSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct SceneWidgetHSettingsView: View {
    @ObservedObject private var model: Model
    @State private var h: String
    private var widget: SettingsSceneWidget
    
    init(model: Model, widget: SettingsSceneWidget) {
        self.model = model
        self.h = "\(widget.h)"
        self.widget = widget
    }
    
    var body: some View {
        Form {
            TextField("", text: $h)
                .onSubmit {
                    if let h = Int(h.trim()) {
                        widget.h = h
                        model.store()
                    }
                }
        }
        .navigationTitle("Height")
    }
}
