import SwiftUI

private struct MacroView: View {
    let model: Model
    @ObservedObject var macro: SettingsMacrosMacro

    var body: some View {
        HStack {
            Text(macro.name)
            Spacer()
            if macro.running {
                Button {
                    model.stopMacro(macro: macro)
                } label: {
                    Text("Cancel")
                }
                .tint(.red)
                .buttonStyle(.borderless)
            } else if macro.finished {
                Text("Finished")
                    .foregroundStyle(.green)
            } else {
                Button {
                    model.startMacro(macro: macro)
                    if macro.closePanelOnRun {
                        model.toggleShowingPanel(type: nil, panel: .none)
                    }
                } label: {
                    if macro.closePanelOnRun {
                        Text("Run and close")
                    } else {
                        Text("Run")
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct QuickButtonMacrosView: View {
    let model: Model
    @ObservedObject var macros: SettingsMacros

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(macros.macros) { macro in
                        MacroView(model: model, macro: macro)
                    }
                }
            }
            ShortcutSectionView {
                NavigationLink {
                    MacrosSettingsView(model: model,
                                       database: model.database,
                                       macros: macros)
                } label: {
                    Label("Macros", systemImage: "increase.indent")
                }
            }
        }
        .navigationTitle("Macros")
    }
}
