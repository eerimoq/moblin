import SwiftUI

struct QuickButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    func isButtonUsed(button: SettingsButton) -> Bool {
        for scene in database.scenes {
            for sceneButton in scene.buttons where sceneButton.buttonId == button.id {
                return true
            }
        }
        return false
    }

    var body: some View {
        Form {
            Text("""
            A list of all scene quick buttons, often to hide and show widgets. A scene button can \
            be used in zero or more scenes.
            """)
            Section {
                List {
                    ForEach(database.buttons) { button in
                        NavigationLink(destination: ButtonSettingsView(
                            button: button,
                            selection: button.type.toString(),
                            selectedWidget: model.database.widgets
                                .firstIndex(where: { widget in
                                    widget.id == button.widget.widgetId
                                }) ?? 0
                        )) {
                            HStack {
                                DraggableItemPrefixView()
                                IconAndTextView(
                                    image: button.systemImageNameOff,
                                    text: button.name
                                )
                                Spacer()
                                if !isButtonUsed(button: button) {
                                    Text("Unused")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .deleteDisabled(isButtonUsed(button: button))
                    }
                    .onMove(perform: { froms, to in
                        database.buttons.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated()
                    })
                    .onDelete(perform: { offsets in
                        database.buttons.remove(atOffsets: offsets)
                        model.sceneUpdated()
                    })
                }
                CreateButtonView(action: {
                    database.buttons.append(SettingsButton(name: "My button"))
                    model.sceneUpdated()
                })
            } footer: {
                Text("Only unused quick buttons can be deleted.")
            }
        }
        .navigationTitle("Quick buttons")
        .toolbar {
            SettingsToolbar()
        }
    }
}
