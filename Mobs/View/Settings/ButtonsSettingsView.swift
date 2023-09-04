//
//  ButtonsSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-03.
//

import SwiftUI

struct ButtonsSettingsView: View {
    @ObservedObject var model: Model

    var database: Database {
        get {
            model.database
        }
    }
    
    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.buttons) { button in
                        NavigationLink(destination: ButtonSettingsView(button: button, model: model)) {
                            Toggle(button.name, isOn: Binding(get: {
                                button.enabled
                            }, set: { value in
                                button.enabled = value
                                model.store()
                            }))
                        }
                    }
                    .onMove(perform: { (froms, to) in
                        database.buttons.move(fromOffsets: froms, toOffset: to)
                        model.store()
                    })
                    .onDelete(perform: { offsets in
                        database.buttons.remove(atOffsets: offsets)
                        model.store()
                    })
                }
                CreateButtonView(action: {
                    database.buttons.append(SettingsButton(name: "My button"))
                    model.store()
                    model.objectWillChange.send()
                })
            }
        }
        .navigationTitle("Buttons")
    }
}
