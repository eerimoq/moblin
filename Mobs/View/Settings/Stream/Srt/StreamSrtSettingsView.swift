//
//  streamNameSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct StreamSrtSettingsView: View {
    @ObservedObject private var model: Model
    private var stream: SettingsStream
    
    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
    }
    
    func submitUrl(value: String) {
        if URL(string: value) == nil {
            return
        }
        stream.srtUrl = value
        model.store()
        model.srtUrlChanged()
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: SensitiveUrlEditView(value: stream.srtUrl, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: stream.srtUrl, sensitive: true)
            }
            Toggle("SRTLA", isOn: Binding(get: {
                stream.srtla
            }, set: { value in
                stream.srtla = value
                model.store()
                if stream.enabled {
                    model.srtlaChanged()
                }
            }))
        }
        .navigationTitle("SRT")
    }
}
