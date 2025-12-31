import SwiftUI

struct ControllerButtonView: View {
    let model: Model
    let functions: [SettingsControllerFunction]
    @Binding var function: SettingsControllerFunction
    @Binding var sceneId: UUID?
    @Binding var widgetId: UUID?

    var body: some View {
        Section {
            Picker("Function", selection: $function) {
                ForEach(functions, id: \.self) {
                    Text($0.toString())
                }
            }
        }
        switch function {
        case .scene:
            Section {
                Picker("Scene", selection: $sceneId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(model.database.scenes) {
                        SceneNameView(scene: $0)
                            .tag($0.id as UUID?)
                    }
                }
            }
        case .widget:
            Section {
                Picker("Widget", selection: $widgetId) {
                    Text("-- None --")
                        .tag(nil as UUID?)
                    ForEach(model.database.widgets) {
                        WidgetNameView(widget: $0)
                            .tag($0.id as UUID?)
                    }
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
