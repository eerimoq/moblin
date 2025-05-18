import SwiftUI

private struct AppearenceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var quickButtons: SettingsQuickButtons

    var body: some View {
        Section {
            if model.database.showAllSettings {
                Toggle("Scroll", isOn: $quickButtons.enableScroll)
                    .onChange(of: quickButtons.enableScroll) { _ in
                        model.updateQuickButtonStates()
                    }
                Toggle("Two columns", isOn: $quickButtons.twoColumns)
                    .onChange(of: quickButtons.twoColumns) { _ in
                        model.updateQuickButtonStates()
                    }
            }
            Toggle("Show name", isOn: $quickButtons.showName)
                .onChange(of: quickButtons.showName) { _ in
                    model.updateQuickButtonStates()
                }
        } header: {
            Text("Appearence")
        } footer: {
            Text("Names are not shown in portrait mode.")
        }
    }
}

private struct ButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Section {
            List {
                ForEach(model.database.globalButtons) { button in
                    if model.database.showAllSettings {
                        NavigationLink {
                            QuickButtonsButtonSettingsView(
                                button: button,
                                shortcut: false
                            )
                        } label: {
                            Toggle(isOn: Binding(get: {
                                button.enabled
                            }, set: { value in
                                button.enabled = value
                                model.updateQuickButtonStates()
                            })) {
                                HStack {
                                    DraggableItemPrefixView()
                                    IconAndTextView(
                                        image: button.systemImageNameOff,
                                        text: button.name,
                                        longDivider: true
                                    )
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        Toggle(isOn: Binding(get: {
                            button.enabled
                        }, set: { value in
                            button.enabled = value
                            model.updateQuickButtonStates()
                        })) {
                            HStack {
                                DraggableItemPrefixView()
                                IconAndTextView(
                                    image: button.systemImageNameOff,
                                    text: button.name,
                                    longDivider: true
                                )
                                Spacer()
                            }
                        }
                    }
                }
                .onMove(perform: { froms, to in
                    model.database.globalButtons.move(fromOffsets: froms, toOffset: to)
                    model.updateQuickButtonStates()
                    model.sceneUpdated(updateRemoteScene: false)
                })
            }
        } header: {
            Text("Quick buttons")
        }
    }
}

struct QuickButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            AppearenceSettingsView(quickButtons: model.database.quickButtons)
            ButtonsSettingsView()
        }
        .navigationTitle("Quick buttons")
    }
}
