import SwiftUI

struct ControllerButtonView: View {
    let model: Model
    let functions: [SettingsControllerFunction]
    @Binding var function: SettingsControllerFunction
    @Binding var sceneId: UUID
    @Binding var widgetId: UUID

    private func onFunctionChange(function: String) {
        self.function = SettingsControllerFunction(rawValue: function) ?? .unused
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: "Function",
                    onChange: onFunctionChange,
                    items: functions.map { .init(id: $0.rawValue, text: $0.toString()) },
                    selectedId: function.rawValue
                )
            } label: {
                TextItemLocalizedView(name: "Function", value: function.toString())
            }
        }
        switch function {
        case .scene:
            Section {
                Picker("", selection: $sceneId) {
                    ForEach(model.database.scenes) { scene in
                        SceneNameView(scene: scene)
                            .tag(scene.id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Scene")
            }
        case .widget:
            Section {
                Picker("", selection: $widgetId) {
                    ForEach(model.database.widgets) { widget in
                        WidgetNameView(widget: widget)
                            .tag(widget.id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Widget")
            }
        default:
            EmptyView()
        }
    }
}

struct GameControllersControllerButtonSettingsView: View {
    let model: Model
    @ObservedObject var button: SettingsGameControllerButton

    var body: some View {
        NavigationLink {
            Form {
                ControllerButtonView(model: model,
                                     functions: SettingsControllerFunction.allCases,
                                     function: $button.function,
                                     sceneId: $button.sceneId,
                                     widgetId: $button.widgetId)
            }
            .navigationTitle("Game controller button")
        } label: {
            Label {
                HStack {
                    Text(button.text)
                    Spacer()
                    Text(button.function.toString(sceneName: model.getSceneName(id: button.sceneId),
                                                  widgetName: model.getWidgetName(id: button.widgetId)))
                        .foregroundStyle(button.function.color())
                }
            } icon: {
                Image(systemName: button.name)
            }
        }
    }
}
