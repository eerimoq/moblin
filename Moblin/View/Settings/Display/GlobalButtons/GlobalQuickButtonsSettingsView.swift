import SwiftUI

struct GlobalQuickButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    private func onBackgroundColorChange(button: SettingsButton, color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        button.backgroundColor = color
        model.updateButtonStates()
    }

    private func onBackgroundColorSubmit() {
        model.store()
    }

    var body: some View {
        Form {
            Section {
                Toggle("Scroll", isOn: Binding(get: {
                    model.database.quickButtons!.enableScroll
                }, set: { value in
                    model.database.quickButtons!.enableScroll = value
                    model.store()
                    model.updateButtonStates()
                    model.scrollQuickButtonsToBottom()
                }))
                Toggle("Two columns", isOn: Binding(get: {
                    model.database.quickButtons!.twoColumns
                }, set: { value in
                    model.database.quickButtons!.twoColumns = value
                    model.store()
                    model.updateButtonStates()
                    model.scrollQuickButtonsToBottom()
                }))
                Toggle("Show name", isOn: Binding(get: {
                    model.database.quickButtons!.showName
                }, set: { value in
                    model.database.quickButtons!.showName = value
                    model.store()
                    model.updateButtonStates()
                    model.scrollQuickButtonsToBottom()
                }))
            } header: {
                Text("Appearence")
            } footer: {
                Text("Names are not shown in portrait mode.")
            }
            Section {
                List {
                    ForEach(model.database.globalButtons!) { button in
                        NavigationLink(destination: GlobalQuickButtonsButtonSettingsView(
                            name: button.name,
                            background: button.backgroundColor!.color(),
                            onChange: { color in onBackgroundColorChange(button: button, color: color) },
                            onSubmit: onBackgroundColorSubmit
                        )) {
                            Toggle(isOn: Binding(get: {
                                button.enabled!
                            }, set: { value in
                                button.enabled = value
                                model.store()
                                model.updateButtonStates()
                            })) {
                                HStack {
                                    DraggableItemPrefixView()
                                    IconAndTextView(
                                        image: button.systemImageNameOff,
                                        text: button.name
                                    )
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onMove(perform: { froms, to in
                        model.database.globalButtons!.move(fromOffsets: froms, toOffset: to)
                        model.updateButtonStates()
                        model.sceneUpdated()
                    })
                }
            } header: {
                Text("Quick buttons")
            }
        }
        .navigationTitle("Quick buttons")
        .toolbar {
            SettingsToolbar()
        }
    }
}
