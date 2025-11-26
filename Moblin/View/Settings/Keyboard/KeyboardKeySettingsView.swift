import SwiftUI

struct KeyboardKeySettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var key: SettingsKeyboardKey

    private func onFunctionChange(function: String) {
        key.function = SettingsKeyboardKeyFunction(rawValue: function) ?? .unused
    }

    private func keyText() -> String {
        switch key.function {
        case .scene:
            return "\(model.getSceneName(id: key.sceneId)) scene"
        default:
            return key.function.toString()
        }
    }

    private func keyColor() -> Color {
        switch key.function {
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
                    TextEditNavigationView(title: String(localized: "Key"),
                                           value: key.key,
                                           onSubmit: {
                                               key.key = $0
                                           })
                }
                Section {
                    NavigationLink {
                        InlinePickerView(
                            title: String(localized: "Function"),
                            onChange: onFunctionChange,
                            items: SettingsKeyboardKeyFunction.allCases
                                .map { .init(id: $0.rawValue, text: $0.toString()) },
                            selectedId: key.function.rawValue
                        )
                    } label: {
                        TextItemView(name: String(localized: "Function"), value: key.function.toString())
                    }
                }
                switch key.function {
                case .scene:
                    Section {
                        Picker("", selection: $key.sceneId) {
                            ForEach(model.database.scenes) { scene in
                                Text(scene.name)
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
                        Picker("", selection: $key.widgetId) {
                            ForEach(model.database.widgets) { widget in
                                Text(widget.name)
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
            .navigationTitle("Keyboard key")
        } label: {
            HStack {
                if key.key.isEmpty {
                    Text("No key set")
                        .foregroundStyle(.gray)
                } else {
                    Text(key.key)
                }
                Spacer()
                Text(keyText())
                    .foregroundStyle(keyColor())
            }
        }
    }
}
