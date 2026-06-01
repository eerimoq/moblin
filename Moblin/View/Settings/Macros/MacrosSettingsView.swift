import SwiftUI

private func isSelected<T>(_ values: Set<T>, _ type: T) -> Bool {
    values.contains(type)
}

private func setSelected<T>(_ values: inout Set<T>, _ type: T, _ selected: Bool) {
    if selected {
        values.insert(type)
    } else {
        values.remove(type)
    }
}

private struct ActionView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var macros: SettingsMacros
    @ObservedObject var action: SettingsMacrosAction

    private func submitZoomX(zoomX: String) {
        guard let zoomX = Float(zoomX) else {
            return
        }
        action.zoomX = max(zoomX, minZoomX)
    }

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
                    case .scene:
                        Picker("Scene", selection: $action.sceneId) {
                            Text("-- None --")
                                .tag(nil as UUID?)
                            ForEach(database.scenes) {
                                SceneNameView(scene: $0)
                                    .tag($0.id as UUID?)
                            }
                        }
                    case .enableDisableScenes:
                        ForEach(database.scenes) { scene in
                            Toggle(scene.name, isOn: Binding(
                                get: {
                                    isSelected(action.sceneIds, scene.id)
                                },
                                set: {
                                    setSelected(&action.sceneIds, scene.id, $0)
                                }
                            ))
                        }
                    case .autoSceneSwitcher:
                        Picker("Auto scene switcher", selection: $action.autoSceneSwitcherId) {
                            Text("-- None --")
                                .tag(nil as UUID?)
                            ForEach(database.autoSceneSwitchers.switchers) {
                                Text($0.name)
                                    .tag($0.id as UUID?)
                            }
                        }
                    case .zoom:
                        TextEditNavigationView(
                            title: String(localized: "X"),
                            value: String(action.zoomX),
                            onSubmit: {
                                submitZoomX(zoomX: $0)
                            },
                            keyboardType: .numbersAndPunctuation
                        )
                    case .gimbalPreset:
                        Picker("Preset", selection: $action.gimbalPresetId) {
                            Text("-- None --")
                                .tag(nil as UUID?)
                            ForEach(database.gimbal.presets) {
                                Text($0.name)
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
                    case .djiDevices:
                        ForEach(database.djiDevices.devices) { device in
                            Toggle(device.name, isOn: Binding(
                                get: {
                                    isSelected(action.djiDevices, device.id)
                                },
                                set: {
                                    setSelected(&action.djiDevices, device.id, $0)
                                }
                            ))
                        }
                    case .record:
                        Picker("Record", selection: $action.record) {
                            Text("Start")
                                .tag(true)
                            Text("Stop")
                                .tag(false)
                        }
                    case .mute:
                        Picker("Mute", selection: $action.mute) {
                            Text("On")
                                .tag(true)
                            Text("Off")
                                .tag(false)
                        }
                    case .torch:
                        Picker("Torch", selection: $action.torch) {
                            Text("On")
                                .tag(true)
                            Text("Off")
                                .tag(false)
                        }
                    case .snapshot:
                        EmptyView()
                    case .filters:
                        ForEach(SettingsQuickButtonType.filters(), id: \.self) { filter in
                            Toggle(filter.toString(), isOn: Binding(
                                get: {
                                    isSelected(action.filters, filter)
                                },
                                set: {
                                    setSelected(&action.filters, filter, $0)
                                }
                            ))
                        }
                    case .reaction:
                        Picker("Reaction", selection: $action.reaction) {
                            ForEach(SettingsReaction.allCases, id: \.self) {
                                Text($0.toString())
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
                case .scene:
                    if let sceneName = model.getSceneName(id: action.sceneId) {
                        Spacer()
                        GrayTextView(text: sceneName)
                    }
                case .enableDisableScenes:
                    Spacer()
                    GrayTextView(text: String(action.sceneIds.count))
                case .autoSceneSwitcher:
                    if let switcherName = database.autoSceneSwitchers.switchers
                        .first(where: { $0.id == action.autoSceneSwitcherId })?
                        .name
                    {
                        Spacer()
                        GrayTextView(text: switcherName)
                    }
                case .zoom:
                    Spacer()
                    GrayTextView(text: formatOneDecimal(action.zoomX))
                case .gimbalPreset:
                    if let presetName = database.gimbal.presets
                        .first(where: { $0.id == action.gimbalPresetId })?
                        .name
                    {
                        Spacer()
                        GrayTextView(text: presetName)
                    }
                case .delay:
                    Spacer()
                    GrayTextView(text: "\(Int(action.delay))s")
                case .macro:
                    if let macroName = macros.macros.first(where: { $0.id == action.macroId })?.name {
                        Spacer()
                        GrayTextView(text: macroName)
                    }
                case .djiDevices:
                    Spacer()
                    GrayTextView(text: String(action.djiDevices.count))
                case .filters:
                    Spacer()
                    GrayTextView(text: String(action.filters.count))
                case .record:
                    Spacer()
                    GrayTextView(text: action.record ? String(localized: "Start") : String(localized: "Stop"))
                case .mute:
                    Spacer()
                    GrayTextView(text: action.mute ? String(localized: "On") : String(localized: "Off"))
                case .torch:
                    Spacer()
                    GrayTextView(text: action.torch ? String(localized: "On") : String(localized: "Off"))
                case .snapshot:
                    EmptyView()
                case .reaction:
                    Spacer()
                    GrayTextView(text: action.reaction.toString())
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
                    SwipeLeftToDeleteHelpView(kind: String(localized: "an action"))
                }
                Section {
                    if macro.running {
                        TextButtonView("Cancel") {
                            model.stopMacro(macro: macro)
                        }
                        .tint(.red)
                    } else if macro.finished {
                        Text("Finished")
                            .hCenter(true)
                            .foregroundStyle(.green)
                    } else {
                        TextButtonView("Run") {
                            model.startMacro(macro: macro)
                        }
                    }
                }
            }
            .navigationTitle("Macro")
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
                Text("""
                A macro is a sequence of actions that can change settings, filters, etc. with a \
                single button tap.
                """)
            }
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
