//
//  ButtonSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-04.
//

import SwiftUI

struct ImageItemView: View {
    var name: String
    var image: String
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: image)
        }
    }
}

struct ButtonSettingsView: View {
    @ObservedObject var model: Model
    private var button: SettingsButton
    @State private var selection: String
    @State private var selectedWidget: Int
    
    init(button: SettingsButton, model: Model) {
        self.button = button
        self.model = model
        self.selection = button.type
        self.selectedWidget = model.database.widgets.firstIndex(where: {
            widget in widget.id == button.widget.widgetId
        }) ?? 0
    }
    
    func submitName(name: String) {
        button.name = name
        model.store()
    }
    
    func onSystemImageNameOn(name: String) {
        button.systemImageNameOn = name
        model.store()
    }
    
    func onSystemImageNameOff(name: String) {
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
            switch selection {
            case "Widget":
                Section("Widget") {
                    Picker("", selection: $selectedWidget) {
                        ForEach(model.database.widgets) { widget in
                            HStack {
                                Image(systemName: widgetImage(widget: widget))
                                Text(widget.name)
                            }
                            .tag(model.database.widgets.firstIndex(of: widget)!)
                        }
                    }
                    .onChange(of: selectedWidget) { index in
                        button.widget.widgetId = model.database.widgets[index].id
                        model.store()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            default:
                EmptyView()
            }
            Section("Images") {
                NavigationLink(destination: ButtonImagePickerSettingsView(title: "On", value: button.systemImageNameOn, onChange: onSystemImageNameOn)) {
                    ImageItemView(name: "On", image: button.systemImageNameOn)
                }
                NavigationLink(destination: ButtonImagePickerSettingsView(title: "Off", value: button.systemImageNameOff, onChange: onSystemImageNameOff)) {
                    ImageItemView(name: "Off", image: button.systemImageNameOff)
                }
            }
            Section {
                ForEach(model.database.scenes) { scene in
                    Toggle(scene.name, isOn: Binding(get: {
                        button.scenes.contains(scene.id)
                    }, set: { value in
                        if value {
                            button.addScene(id: scene.id)
                        } else {
                            button.removeScene(id: scene.id)
                        }
                        model.store()
                        model.sceneUpdated()
                    }))
                }
            } header: {
                Text("Scenes")
            } footer: {
                Text("The button appears when any selected scene is active.")
            }
        }
        .navigationTitle("Button")
    }
}
