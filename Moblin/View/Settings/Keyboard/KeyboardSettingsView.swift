import SwiftUI

struct KeyboardSettingsView: View {
    @ObservedObject var keyboard: SettingsKeyboard

    var body: some View {
        Form {
            Section {
                Text("Use a keyboard to zoom, set scene, and more.")
            }
            Section {
                List {
                    ForEach(keyboard.keys) { key in
                        KeyboardKeySettingsView(key: key)
                    }
                    .onDelete { indexSet in
                        keyboard.keys.remove(atOffsets: indexSet)
                    }
                }
                CreateButtonView {
                    keyboard.keys.append(SettingsKeyboardKey())
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a key"))
            }
        }
        .navigationTitle("Keyboard")
    }
}
