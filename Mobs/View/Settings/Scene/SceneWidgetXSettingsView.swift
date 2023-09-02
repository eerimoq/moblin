//
//  SceneWidgetXSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct SceneWidgetXSettingsView: View {
    @ObservedObject private var model: Model
    @State private var x: String
    private var widget: SettingsSceneWidget
    
    init(model: Model, widget: SettingsSceneWidget) {
        self.model = model
        self.x = "\(widget.x)"
        self.widget = widget
    }
    
    var body: some View {
        Form {
            TextField("", text: $x)
                .onSubmit {
                    if let x = Int(x.trim()) {
                        widget.x = x
                        model.store()
                    }
                }
        }
        .navigationTitle("X")
    }
}
