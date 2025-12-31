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
    let model: Model
    @ObservedObject var key: SettingsKeyboardKey

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
                ControllerButtonView(model: model,
                                     functions: SettingsControllerFunction.allCases
                                         .filter { $0 != .zoomIn && $0 != .zoomOut },
                                     function: $key.function,
                                     sceneId: $key.sceneId,
                                     widgetId: $key.widgetId)
            }
            .navigationTitle("Keyboard key")
        } label: {
            HStack {
                SelectedKeyView(key: key)
                Spacer()
                Text(key.function.toString(sceneName: model.getSceneName(id: key.sceneId),
                                           widgetName: model.getWidgetName(id: key.widgetId)))
                    .foregroundStyle(key.function.color())
            }
        }
    }
}
