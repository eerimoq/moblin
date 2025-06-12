import SwiftUI

struct QuickButtonsButtonSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var button: SettingsQuickButton
    let shortcut: Bool

    private func onColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        button.backgroundColor = color
        model.updateQuickButtonStates()
    }

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $button.color, supportsOpacity: false)
                    .onChange(of: button.color) { _ in
                        onColorChange(color: button.color)
                    }
                Button {
                    button.color = defaultQuickButtonColor.color()
                    onColorChange(color: button.color)
                } label: {
                    HCenter {
                        Text("Reset")
                    }
                }
            } header: {
                Text("Color")
            }
            if #available(iOS 17, *) {
                Section {
                    Picker(selection: $button.page) {
                        ForEach(1 ... controlBarPages, id: \.self) { page in
                            Text(String(page))
                                .tag(page as Int?)
                        }
                    } label: {
                        Text("Page")
                    }
                    .onChange(of: button.page) { _ in
                        model.updateQuickButtonStates()
                    }
                }
            }
            if shortcut {
                Section {
                    NavigationLink {
                        QuickButtonsSettingsView()
                    } label: {
                        Label("Quick buttons", systemImage: "rectangle.inset.topright.fill")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
        }
        .navigationTitle(button.name)
    }
}
