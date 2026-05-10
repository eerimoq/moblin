import SwiftUI

struct ControllerButtonView: View {
    let model: Model
    let functions: [SettingsControllerFunction]
    @Binding var function: SettingsControllerFunction
    @Binding var functionData: SettingsControllerFunctionData

    var body: some View {
        Picker("Function", selection: $function) {
            Section("General") {
                ForEach(functions.filter { $0.section() == .general }, id: \.self) {
                    Text($0.toString())
                }
            }
            Section("Filters") {
                ForEach(functions.filter { $0.section() == .filters }, id: \.self) {
                    Text($0.toString())
                }
            }
        }
        switch function {
        case .scene:
            Picker("Scene", selection: $functionData.sceneId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(model.database.scenes) {
                    SceneNameView(scene: $0)
                        .tag($0.id as UUID?)
                }
            }
        case .widget:
            Picker("Widget", selection: $functionData.widgetId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(model.database.widgets) {
                    WidgetNameView(widget: $0)
                        .tag($0.id as UUID?)
                }
            }
        case .gimbalPreset:
            Picker("Preset", selection: $functionData.gimbalPresetId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(model.database.gimbal.presets) {
                    Text($0.name)
                        .tag($0.id as UUID?)
                }
            }
        case .gimbalAnimate:
            Picker("Motion", selection: $functionData.gimbalMotion) {
                ForEach(SettingsGimbalMotion.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
        case .macro:
            Picker("Macro", selection: $functionData.macroId) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(model.database.macros.macros) {
                    Text($0.name)
                        .tag($0.id as UUID?)
                }
            }
        default:
            EmptyView()
        }
    }
}

struct GameControllersControllerButtonSettingsView: View {
    let model: Model
    @ObservedObject var button: SettingsGameControllerButton

    private func functions() -> [SettingsControllerFunction] {
        SettingsControllerFunction.allCases
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    ControllerButtonView(model: model,
                                         functions: functions(),
                                         function: $button.function,
                                         functionData: $button.functionData)
                }
            }
            .navigationTitle("Button")
        } label: {
            Label {
                HStack {
                    Text(button.text)
                    Spacer()
                    Text(button.function.toString(
                        sceneName: model.getSceneName(id: button.functionData.sceneId),
                        widgetName: model.getWidgetName(id: button.functionData.widgetId)
                    ))
                    .foregroundStyle(button.function.color())
                }
            } icon: {
                Image(systemName: button.name)
            }
        }
    }
}
