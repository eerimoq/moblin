import SwiftUI

private struct AppearanceSettingsView: View {
    @ObservedObject var database: Database
    @ObservedObject var quickButtons: SettingsQuickButtons

    var body: some View {
        Section {
            if database.showAllSettings {
                Toggle("Scroll", isOn: $quickButtons.enableScroll)
                Toggle("Two columns", isOn: $quickButtons.twoColumns)
            }
            Toggle("Big buttons", isOn: $quickButtons.bigButtons)
            Toggle("Show name", isOn: $quickButtons.showName)
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

    var body: some View {
        NavigationLink {
            QuickButtonsButtonSettingsView(model: model,
                                           orientation: model.orientation,
                                           quickButtonsSettings: model.database.quickButtonsGeneral,
                                           button: button,
                                           showAll: false)
                .onAppear {
                    model.quickButtons.selectedButtonType = button.type
                    model.quickButtons.page = button.page
                    model.quickButtons.activePage = button.page
                }
                .onDisappear {
                    if model.showingPanel != .quickButtonSettings {
                        model.quickButtons.selectedButtonType = nil
                    }
                }
        } label: {
            Toggle(isOn: $button.enabled) {
                IconAndTextView(
                    image: button.imageOff,
                    text: button.name,
                    longDivider: true
                )
            }
            .disabled(button.isOn && button.enabled)
            .onChange(of: button.enabled) { _ in
                model.updateQuickButtonPairs()
            }
        }
    }
}

private struct ButtonsSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @State private var filter = ""

    private func buttons(page: Int) -> [SettingsQuickButton] {
        database.quickButtons.reversed().filter { button in
            guard button.page == page else {
                return false
            }
            return filter.isEmpty || button.name.lowercased().contains(filter.lowercased())
        }
    }

    var body: some View {
        Section {
            TextField("Filter", text: $filter)
                .autocorrectionDisabled()
        }
        ForEach(1 ... controlBarPages, id: \.self) { page in
            let buttons = buttons(page: page)
            if !buttons.isEmpty {
                Section {
                    List {
                        ForEach(buttons) { button in
                            ButtonSettingsView(model: model, button: button)
                        }
                    }
                } header: {
                    Text("Page \(page)")
                }
            }
        }
    }
}

struct QuickButtonsSettingsView: View {
    let model: Model
    let showAll: Bool

    var body: some View {
        Form {
            AppearanceSettingsView(database: model.database,
                                   quickButtons: model.database.quickButtonsGeneral)
            if showAll {
                ButtonsSettingsView(model: model, database: model.database)
            }
        }
        .navigationTitle("Quick buttons")
    }
}
