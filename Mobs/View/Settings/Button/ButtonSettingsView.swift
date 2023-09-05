//
//  ButtonSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-04.
//

import SwiftUI

struct ButtonSettingsView: View {
    @ObservedObject var model: Model
    private var button: SettingsButton
    @State private var selection: String
    
    init(button: SettingsButton, model: Model) {
        self.button = button
        self.model = model
        self.selection = button.type
    }
    
    func submitName(name: String) {
        button.name = name
        model.store()
    }
    
    func submitSystemImageNameOn(name: String) {
        button.systemImageNameOn = name
        model.store()
    }
    
    func submitSystemImageNameOff(name: String) {
        button.systemImageNameOff = name
        model.store()
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(name: button.name, onSubmit: submitName)) {
                TextItemView(name: "Name", value: button.name)
            }
            Section("Type") {
                Picker("", selection: $selection) {
                    ForEach(buttonTypes, id: \.self) { type in
                        Text(type)
                    }
                }
                .onChange(of: selection) { type in
                    button.type = type
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section("Image") {
                NavigationLink(destination: TextEditView(title: "System name on", value: button.systemImageNameOn, onSubmit: submitSystemImageNameOn)) {
                    TextItemView(name: "System name on", value: button.systemImageNameOn)
                }
                NavigationLink(destination: TextEditView(title: "System name off", value: button.systemImageNameOff, onSubmit: submitSystemImageNameOff)) {
                    TextItemView(name: "System name off", value: button.systemImageNameOff)
                }
            }
        }
        .navigationTitle("Button")
    }
}
