import SwiftUI

private struct SelectedKeyView: View {
    @ObservedObject var key: SettingsKeyboardKey

    var body: some View {
        if key.key.isEmpty {
            Text("No key set")
                .foregroundStyle(.gray)
        } else {
            Text(key.key)
        }
    }
}

private struct KeyPickerView: View {
    @ObservedObject var key: SettingsKeyboardKey
    @FocusState var editingText: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TextField("No key set", text: $key.key)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($editingText)
            .onChange(of: key.key) { _ in
                guard !key.key.isEmpty else {
                    return
                }
                dismiss()
            }
            .onSubmit {
                dismiss()
            }
            .onChange(of: editingText) { _ in
                guard editingText else {
                    return
                }
                key.key = ""
            }
    }
}

struct KeyboardKeySettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var key: SettingsKeyboardKey

    private func onFunctionChange(function: String) {
        key.function = SettingsControllerFunction(rawValue: function) ?? .unused
    }

    private func keyText() -> String {
        switch key.function {
        case .scene:
            return String(localized: "\(model.getSceneName(id: key.sceneId)) scene")
        case .widget:
            return String(localized: "\(model.getWidgetName(id: key.widgetId)) widget")
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
                    NavigationLink {
                        Form {
                            KeyPickerView(key: key)
                        }
                        .navigationTitle("Key")
                    } label: {
                        HStack {
                            Text("Key")
                            Spacer()
                            SelectedKeyView(key: key)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        InlinePickerView(
                            title: String(localized: "Function"),
                            onChange: onFunctionChange,
                            items: SettingsControllerFunction.allCases
                                .filter { $0 != .zoomIn && $0 != .zoomOut }
                                .map { .init(id: $0.rawValue, text: $0.toString()) },
                            selectedId: key.function.rawValue
                        )
                    } label: {
                        TextItemLocalizedView(name: "Function", value: key.function.toString())
                    }
                }
                switch key.function {
                case .scene:
                    Section {
                        Picker("", selection: $key.sceneId) {
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
                        Picker("", selection: $key.widgetId) {
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
            .navigationTitle("Keyboard key")
        } label: {
            HStack {
                SelectedKeyView(key: key)
                Spacer()
                Text(keyText())
                    .foregroundStyle(keyColor())
            }
        }
    }
}
