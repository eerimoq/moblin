import SwiftUI

struct GameControllersControllerButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var button: SettingsGameControllerButton

    private func onFunctionChange(function: String) {
        button.function = SettingsControllerFunction(rawValue: function) ?? .unused
    }

    private func buttonText() -> String {
        switch button.function {
        case .scene:
            return String(localized: "\(model.getSceneName(id: button.sceneId)) scene")
        case .widget:
            return String(localized: "\(model.getWidgetName(id: button.widgetId)) widget")
        default:
            return button.function.toString()
        }
    }

    private func buttonColor() -> Color {
        switch button.function {
        case .unused:
            return .gray
        default:
            return .primary
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NavigationLink {
                        InlinePickerView(
                            title: String(localized: "Function"),
                            onChange: onFunctionChange,
                            items: SettingsControllerFunction.allCases.map { .init(
                                id: $0.rawValue,
                                text: $0.toString()
                            ) },
                            selectedId: button.function.rawValue
                        )
                    } label: {
                        TextItemView(name: String(localized: "Function"), value: button.function.toString())
                    }
                }
                switch button.function {
                case .scene:
                    Section {
                        Picker("", selection: $button.sceneId) {
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
                        Picker("", selection: $button.widgetId) {
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
            .navigationTitle("Game controller button")
        } label: {
            Label {
                HStack {
                    Text(button.text)
                    Spacer()
                    Text(buttonText())
                        .foregroundStyle(buttonColor())
                }
            } icon: {
                Image(systemName: button.name)
            }
        }
    }
}
