//
//  SceneNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct SceneNameSettingsView: View {
    @ObservedObject private var model: Model
    @State private var name: String
    private var scene: SettingsScene
    
    init(model: Model, scene: SettingsScene) {
        self.model = model
        self.name = scene.name
        self.scene = scene
    }
    
    var body: some View {
        Form {
            TextField("", text: $name)
                .onSubmit {
                    scene.name = name.trim()
                    model.store()
                    model.numberOfScenes += 0
            }
        }
        .navigationTitle("Name")
    }
}
