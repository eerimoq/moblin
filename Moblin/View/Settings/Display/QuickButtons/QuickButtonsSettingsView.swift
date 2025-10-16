import SwiftUI

private struct AppearanceSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var quickButtons: SettingsQuickButtons

    var body: some View {
        Section {
            if database.showAllSettings {
                Toggle("Scroll", isOn: $quickButtons.enableScroll)
                    .onChange(of: quickButtons.enableScroll) { _ in
                        model.updateQuickButtonStates()
                    }
                Toggle("Two columns", isOn: $quickButtons.twoColumns)
                    .onChange(of: quickButtons.twoColumns) { _ in
                        model.updateQuickButtonStates()
                    }
            }
            Toggle("Big buttons", isOn: $quickButtons.bigButtons)
                .onChange(of: quickButtons.bigButtons) { _ in
                    model.updateQuickButtonStates()
                }
            Toggle("Show name", isOn: $quickButtons.showName)
                .onChange(of: quickButtons.showName) { _ in
                    model.updateQuickButtonStates()
                }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Names are not shown in portrait mode.")
        }
    }
}

private struct ButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var button: SettingsQuickButton
    @ObservedObject var state: ButtonState

    private func label() -> some View {
        Toggle(isOn: $button.enabled) {
            HStack {
                DraggableItemPrefixView()
                IconAndTextView(
                    image: button.imageOff,
                    text: button.name,
                    longDivider: true
                )
                Spacer()
            }
        }
        .disabled(state.isOn && button.enabled)
        .onChange(of: button.enabled) { _ in
            model.updateQuickButtonStates()
        }
    }

    var body: some View {
        if model.database.showAllSettings {
            NavigationLink {
                QuickButtonsButtonSettingsView(quickButtons: model.database.quickButtonsGeneral,
                                               button: button,
                                               shortcut: false)
            } label: {
                label()
            }
        } else {
            label()
        }
    }
}

private struct ButtonsSettingsView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        Section {
            List {
                ForEach(database.quickButtons) { button in
                    ButtonSettingsView(button: button,
                                       state: model.getQuickButtonState(type: button.type)
                                           ?? ButtonState(isOn: false, button: button))
                }
                .onMove { froms, to in
                    database.quickButtons.move(fromOffsets: froms, toOffset: to)
                    model.updateQuickButtonStates()
                    model.sceneUpdated(updateRemoteScene: false)
                }
            }
        } header: {
            Text("Quick buttons")
        }
    }
}

struct QuickButtonsSettingsView: View {
    let model: Model

    var body: some View {
        Form {
            AppearanceSettingsView(model: model,
                                   database: model.database,
                                   quickButtons: model.database.quickButtonsGeneral)
            ButtonsSettingsView(model: model, database: model.database)
        }
        .navigationTitle("Quick buttons")
    }
}
