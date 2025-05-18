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

private struct ButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var button: SettingsQuickButton

    private func label() -> some View {
        Toggle(isOn: $button.enabled) {
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
        .onChange(of: button.enabled) { _ in
            model.updateQuickButtonStates()
        }
    }

    var body: some View {
        if model.database.showAllSettings {
            NavigationLink {
                QuickButtonsButtonSettingsView(button: button, shortcut: false)
            } label: {
                label()
            }
        } else {
            label()
        }
    }
}

private struct ButtonsSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Section {
            List {
                ForEach(model.database.quickButtons) { button in
                    ButtonSettingsView(button: button)
                }
                .onMove(perform: { froms, to in
                    model.database.quickButtons.move(fromOffsets: froms, toOffset: to)
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
            AppearenceSettingsView(quickButtons: model.database.quickButtonsGeneral)
            ButtonsSettingsView()
        }
        .navigationTitle("Quick buttons")
    }
}
