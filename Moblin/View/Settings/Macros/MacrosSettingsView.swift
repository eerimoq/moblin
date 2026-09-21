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

struct MacroActionIfBar {
    let level: Int
    let isFirst: Bool
    let isLast: Bool
}

func macroActionIfBars(actions: [SettingsMacrosAction]) -> [[MacroActionIfBar]] {
    var blocks: [(end: Int, level: Int)] = []
    var bars: [[MacroActionIfBar]] = []
    for (index, action) in actions.enumerated() {
        blocks.removeAll(where: { $0.end <= index })
        var firstLevel: Int?
        if action.function == .ifCondition, action.ifRunCount > 0 {
            var level = 0
            while blocks.contains(where: { $0.level == level }) {
                level += 1
            }
            blocks.append((min(index + 1 + action.ifRunCount, actions.count), level))
            firstLevel = level
        }
        bars.append(blocks.map { MacroActionIfBar(level: $0.level,
                                                  isFirst: $0.level == firstLevel,
                                                  isLast: $0.end == index + 1) })
    }
    return bars
}

private let macroActionIfColors: [Color] = [.blue, .purple, .orange, .teal]

private struct ActionIfBarsView: View {
    let bars: [MacroActionIfBar]

    private func bar(level: Int) -> some View {
        let bar = bars.first(where: { $0.level == level })
        return VStack(spacing: 0) {
            if bar?.isFirst == true {
                Color.clear
            }
            Rectangle()
                .fill(bar != nil ? macroActionIfColors[level % macroActionIfColors.count] : .clear)
                .padding(.bottom, bar?.isLast == true ? 4 : 0)
        }
        .frame(width: 3)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< ((bars.map(\.level).max() ?? -1) + 1), id: \.self) {
                bar(level: $0)
            }
            Spacer()
        }
        .padding(.leading, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }
}

private struct TextFormatView: View {
    @EnvironmentObject var model: Model
    let title: String
    let suggestions: Bool
    @Binding var text: String
    @State var value: String

    var body: some View {
        Form {
            TextWidgetTextView(value: $value)
            TextFormatWarningsView(model: model, location: model.database.location, value: $value)
            if suggestions {
                Section {
                    TextWidgetSuggestionsView(widget: false, text: $value)
                }
            }
            TextFormatVariablesView(widget: false, value: $value)
        }
        .onChange(of: value) { _ in
            text = value
            model.macrosTextFormatChanged()
        }
        .navigationTitle(title)
    }
}

private struct ActionView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var macros: SettingsMacros
    @ObservedObject var macro: SettingsMacrosMacro
    @ObservedObject var action: SettingsMacrosAction
    let ifBars: [MacroActionIfBar]

    private func submitZoomX(zoomX: String) {
        guard let zoomX = Float(zoomX), zoomX.isFinite else {
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
                    case .sendChatMessage:
                        NavigationLink {
                            TextFormatView(title: String(localized: "Message"),
                                           suggestions: true,
                                           text: $action.chatMessage,
                                           value: action.chatMessage)
                        } label: {
                            TextItemLocalizedView(name: "Message", value: action.chatMessage)
                        }
                    case .delay:
                        HStack {
                            Text("Delay")
                            Slider(value: $action.delay, in: 1 ... 60)
                            Text("\(Int(action.delay))s")
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
                    case .waitForEvent:
                        Picker("Event", selection: $action.event) {
                            ForEach(SettingsMacrosEvent.allCases, id: \.self) {
                                Text($0.toString())
                            }
                        }
                        .onChange(of: action.event) { _ in
                            action.eventMinimumAmount = 0
                            action.eventText = ""
                            action.eventSceneId = nil
                        }
                        if let title = action.event.minimumAmountTitle() {
                            TextEditNavigationView(
                                title: title,
                                value: String(action.eventMinimumAmount),
                                onSubmit: {
                                    action.eventMinimumAmount = Int($0) ?? 0
                                },
                                keyboardType: .numbersAndPunctuation
                            )
                        }
                        if let title = action.event.textTitle() {
                            TextEditNavigationView(
                                title: title,
                                value: action.eventText,
                                onSubmit: {
                                    action.eventText = $0
                                }
                            )
                        }
                        if action.event == .switchScene {
                            Picker("Scene", selection: $action.eventSceneId) {
                                Text("-- Any --")
                                    .tag(nil as UUID?)
                                ForEach(database.scenes) {
                                    SceneNameView(scene: $0)
                                        .tag($0.id as UUID?)
                                }
                            }
                        }
                    case .ifCondition:
                        NavigationLink {
                            TextFormatView(title: String(localized: "Value"),
                                           suggestions: false,
                                           text: $action.ifValue,
                                           value: action.ifValue)
                        } label: {
                            TextItemLocalizedView(name: "Value", value: action.ifValue)
                        }
                        Picker("Comparison", selection: $action.ifComparison) {
                            ForEach(SettingsMacrosActionIfComparison.allCases, id: \.self) {
                                Text($0.toString())
                            }
                        }
                        NavigationLink {
                            TextFormatView(title: String(localized: "Other value"),
                                           suggestions: false,
                                           text: $action.ifOtherValue,
                                           value: action.ifOtherValue)
                        } label: {
                            TextItemLocalizedView(name: "Other value", value: action.ifOtherValue)
                        }
                        Picker("Actions to run", selection: $action.ifRunCount) {
                            ForEach(1 ... 10, id: \.self) {
                                Text(String($0))
                            }
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
                } footer: {
                    switch action.function {
                    case .waitForEvent:
                        switch action.event {
                        case .twitchReward, .kickReward:
                            Text("""
                            Wait until a viewer redeems the reward, then continue with the following \
                            actions. Leave reward empty to wait for any reward.
                            """)
                        default:
                            Text("Wait until the event happens, then continue with the following actions.")
                        }
                    case .ifCondition:
                        Text("Run given number of following actions if the condition is met.")
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Action")
            .onChange(of: action.function) { _ in
                macro.objectWillChange.send()
            }
            .onChange(of: action.ifRunCount) { _ in
                macro.objectWillChange.send()
            }
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
                case .sendChatMessage:
                    Spacer()
                    GrayTextView(text: action.chatMessage)
                case .delay:
                    Spacer()
                    GrayTextView(text: "\(Int(action.delay))s")
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
                case .waitForEvent:
                    Spacer()
                    if action.event == .switchScene,
                       let sceneName = model.getSceneName(id: action.eventSceneId)
                    {
                        GrayTextView(text: "\(action.event.toString()) (\(sceneName))")
                    } else if !action.eventText.isEmpty {
                        GrayTextView(text: "\(action.event.toString()) (\(action.eventText))")
                    } else {
                        GrayTextView(text: action.event.toString())
                    }
                case .ifCondition:
                    Spacer()
                    GrayTextView(
                        text: "\(action.ifValue) \(action.ifComparison.toString()) \(action.ifOtherValue)"
                    )
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
        .listRowBackground(ActionIfBarsView(bars: ifBars))
        .contextMenuDeleteButton {
            macro.actions.removeAll(where: { $0 === action })
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
                        .onChange(of: macro.name) { _ in
                            model.remoteControlMacrosStateChanged()
                        }
                }
                Section {
                    List {
                        let ifBars = macroActionIfBars(actions: macro.actions)
                        ForEach(Array(macro.actions.enumerated()), id: \.element.id) { index, action in
                            ActionView(model: model,
                                       database: database,
                                       macros: macros,
                                       macro: macro,
                                       action: action,
                                       ifBars: ifBars[index])
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
                    Picker("Repeat", selection: $macro.repeatMode) {
                        ForEach(SettingsMacrosMacroRepeatMode.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    if macro.repeatMode == .count {
                        TextEditNavigationView(title: String(localized: "Count"),
                                               value: String(macro.repeatCount))
                        {
                            guard let count = Int($0) else {
                                return
                            }
                            macro.repeatCount = count.clamped(to: 1 ... 1_000_000)
                        }
                    }
                }
                Section {
                    Toggle("Close macros panel on run", isOn: $macro.closePanelOnRun)
                    Toggle("Run at app start", isOn: $macro.runAtAppStart)
                } footer: {
                    Text("""
                    Run at app start is useful for macros that wait for events, for example to run \
                    actions when someone follows. Set repeat to forever to wait again after each event.
                    """)
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
        .contextMenuDeleteButton {
            model.stopMacro(macro: macro)
            macros.macros.removeAll(where: { $0 === macro })
            model.remoteControlMacrosStateChanged()
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
                single button tap. It can also wait for events, for example new followers, before \
                continuing.
                """)
            }
            Section {
                List {
                    ForEach(macros.macros) {
                        MacroView(model: model, database: database, macros: macros, macro: $0)
                    }
                    .onMove { froms, to in
                        macros.macros.move(fromOffsets: froms, toOffset: to)
                        model.remoteControlMacrosStateChanged()
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            model.stopMacro(macro: macros.macros[offset])
                        }
                        macros.macros.remove(atOffsets: offsets)
                        model.remoteControlMacrosStateChanged()
                    }
                }
                CreateButtonView {
                    let macro = SettingsMacrosMacro()
                    macro.name = makeUniqueName(
                        name: SettingsMacrosMacro.baseName,
                        existingNames: macros.macros
                    )
                    macros.macros.append(macro)
                    model.remoteControlMacrosStateChanged()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a macro"))
            }
        }
        .navigationTitle("Macros")
    }
}
