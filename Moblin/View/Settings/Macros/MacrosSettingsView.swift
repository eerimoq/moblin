import SwiftUI

private struct ActionView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var macros: SettingsMacros
    @ObservedObject var action: SettingsMacrosAction

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Picker("Function", selection: $action.function) {
                        Text("-- None --")
                            .tag(nil as SettingsMacrosActionFunction?)
                        ForEach(SettingsMacrosActionFunction.allCases, id: \.self) {
                            Text($0.toString())
                                .tag($0 as SettingsMacrosActionFunction?)
                        }
                    }
                    switch action.function {
                    case .enableScene, .disableScene, .scene:
                        Picker("Scene", selection: $action.sceneId) {
                            Text("-- None --")
                                .tag(nil as UUID?)
                            ForEach(database.scenes) {
                                SceneNameView(scene: $0)
                                    .tag($0.id as UUID?)
                            }
                        }
                    case .delay:
                        HStack {
                            Text("Delay")
                            Slider(value: $action.delay, in: 1 ... 60)
                            Text("\(Int(action.delay))s")
                        }
                    case .macro:
                        Picker("Macro", selection: $action.macroId) {
                            Text("-- None --")
                                .tag(nil as UUID?)
                            ForEach(macros.macros) {
                                Text($0.name)
                                    .tag($0.id as UUID?)
                            }
                        }
                    case nil:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Action")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(action.function?.toString() ?? String(localized: "-- None --"))
                switch action.function {
                case .enableScene, .disableScene, .scene:
                    if let sceneName = model.getSceneName(id: action.sceneId) {
                        Spacer()
                        GrayTextView(text: sceneName)
                    }
                case .delay:
                    Spacer()
                    GrayTextView(text: "\(Int(action.delay))s")
                case .macro:
                    if let macroName = macros.macros.first(where: { $0.id == action.macroId })?.name {
                        Spacer()
                        GrayTextView(text: macroName)
                    }
                case nil:
                    EmptyView()
                }
            }
        }
    }
}

private struct MacroView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var macros: SettingsMacros
    @ObservedObject var macro: SettingsMacrosMacro

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $macro.name, existingNames: macros.macros)
                }
                Section {
                    List {
                        ForEach(macro.actions) {
                            ActionView(model: model, database: database, macros: macros, action: $0)
                        }
                        .onMove { froms, to in
                            macro.actions.move(fromOffsets: froms, toOffset: to)
                        }
                        .onDelete { offsets in
                            macro.actions.remove(atOffsets: offsets)
                        }
                    }
                    CreateButtonView {
                        macro.actions.append(SettingsMacrosAction())
                    }
                } header: {
                    Text("Actions")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a action"))
                }
                Section {
                    if macro.running {
                        TextButtonView("Cancel") {
                            model.stopMacro(macro: macro)
                        }
                        .tint(.red)
                    } else {
                        TextButtonView("Run") {
                            model.startMacro(macro: macro)
                        }
                    }
                }
            }
            .navigationTitle(macro.name)
        } label: {
            Text(macro.name)
        }
    }
}

struct MacrosSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var macros: SettingsMacros

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(macros.macros) {
                        MacroView(model: model, database: database, macros: macros, macro: $0)
                    }
                    .onMove { froms, to in
                        macros.macros.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        macros.macros.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    let macro = SettingsMacrosMacro()
                    macro.name = makeUniqueName(
                        name: SettingsMacrosMacro.baseName,
                        existingNames: macros.macros
                    )
                    macros.macros.append(macro)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a macro"))
            }
        }
        .navigationTitle("Macros")
    }
}
