import SwiftUI

struct KeyboardSettingsView: View {
    @EnvironmentObject var model: Model

    private func keyText(key: SettingsKeyboardKey) -> String {
        switch key.function {
        case .scene:
            return "\(model.getSceneName(id: key.sceneId)) scene"
        default:
            return key.function.toString()
        }
    }

    private func keyColor(key: SettingsKeyboardKey) -> Color {
        switch key.function {
        case .unused:
            return .gray
        default:
            return .primary
        }
    }

    var body: some View {
        Form {
            Section {
                Text("Use a keyboard to zoom, set scene, and more.")
            }
            Section {
                List {
                    ForEach(model.database.keyboard!.keys) { key in
                        NavigationLink {
                            KeyboardKeySettingsView(
                                key: key,
                                selection: key.function.toString(),
                                sceneSelection: key.sceneId,
                                widgetSelection: key.widgetId!
                            )
                        } label: {
                            HStack {
                                Text(key.key)
                                Spacer()
                                Text(keyText(key: key))
                                    .foregroundColor(keyColor(key: key))
                            }
                        }
                    }
                    .onDelete(perform: { indexSet in
                        model.database.keyboard!.keys.remove(atOffsets: indexSet)
                    })
                }
                CreateButtonView {
                    model.database.keyboard!.keys.append(SettingsKeyboardKey())
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a key"))
            }
        }
        .navigationTitle("Keyboard")
    }
}
