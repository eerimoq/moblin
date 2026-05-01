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
            } else {
                Button {
                    model.startMacro(macro: macro)
                } label: {
                    Text("Run")
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
