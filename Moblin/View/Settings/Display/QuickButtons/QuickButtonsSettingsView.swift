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
    let model: Model
    @ObservedObject var button: SettingsQuickButton
    @ObservedObject var state: ButtonState

    var body: some View {
        Toggle(isOn: $button.enabled) {
            IconAndTextView(
                image: button.imageOff,
                text: button.name,
                longDivider: true
            )
        }
        .disabled(state.isOn && button.enabled)
        .onChange(of: button.enabled) { _ in
            model.updateQuickButtonStates()
        }
    }
}

private struct ButtonsSettingsView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        ForEach(1 ... controlBarPages, id: \.self) { page in
            Section {
                List {
                    ForEach(database.quickButtons.reversed().filter { $0.page == page }) { button in
                        ButtonSettingsView(model: model,
                                           button: button,
                                           state: model.getQuickButtonState(type: button.type)
                                               ?? ButtonState(isOn: false, button: button))
                    }
                }
            } header: {
                Text("Page \(page)")
            }
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
