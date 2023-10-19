import SwiftUI

struct ButtonsSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

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
            Section {
                List {
                    ForEach(database.buttons) { button in
                        NavigationLink(destination: ButtonSettingsView(
                            button: button,
                            model: model,
                            toolbar: toolbar
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
                Text("Only unused buttons can be deleted.")
            }
        }
        .navigationTitle("Buttons")
        .toolbar {
            toolbar
        }
    }
}
