//
//  SceneWidgetySettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct SceneWidgetYSettingsView: View {
    @ObservedObject private var model: Model
    @State private var y: String
    private var widget: SettingsSceneWidget
    
    init(model: Model, widget: SettingsSceneWidget) {
        self.model = model
        self.y = "\(widget.y)"
        self.widget = widget
    }
    
    var body: some View {
        Form {
            TextField("", text: $y)
                .onSubmit {
                    if let y = Int(y.trim()) {
                        widget.y = y
                        model.store()
                    }
                }
        }
        .navigationTitle("Y")
    }
}
