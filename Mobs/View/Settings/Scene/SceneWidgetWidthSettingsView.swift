//
//  SceneWidgetXSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct SceneWidgetWSettingsView: View {
    @ObservedObject private var model: Model
    @State private var w: String
    private var widget: SettingsSceneWidget
    
    init(model: Model, widget: SettingsSceneWidget) {
        self.model = model
        self.w = "\(widget.w)"
        self.widget = widget
    }
    
    var body: some View {
        Form {
            TextField("", text: $w)
                .onSubmit {
                    if let w = Int(w.trim()) {
                        widget.w = w
                        model.store()
                    }
                }
        }
        .navigationTitle("Width")
    }
}
