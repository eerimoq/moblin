import SwiftUI

struct StreamButtonsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var background: Color
    @State var foreground: Color

    private func onBackgroundColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        model.database.streamButtonBackgroundColor = color
        model.updateButtonStates()
    }

    private func onForegroundColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        model.database.streamButtonForegroundColor = color
        model.updateButtonStates()
    }

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $background, supportsOpacity: false)
                    .onChange(of: background) { _ in
                        onBackgroundColorChange(color: background)
                    }
                    .onDisappear {
                        model.store()
                    }
                ColorPicker("Foreground", selection: $foreground, supportsOpacity: false)
                    .onChange(of: foreground) { _ in
                        onForegroundColorChange(color: foreground)
                    }
                    .onDisappear {
                        model.store()
                    }
                Button(action: {
                    background = defaultStreamButtonBackgroundColor.color()
                    onBackgroundColorChange(color: background)
                    foreground = defaultStreamButtonForegroundColor.color()
                    onForegroundColorChange(color: foreground)
                    model.store()
                }, label: {
                    HStack {
                        Spacer()
                        Text("Reset")
                        Spacer()
                    }
                })
            } header: {
                Text("Color")
            }
        }
        .navigationTitle("Stream button")
        .toolbar {
            SettingsToolbar()
        }
    }
}
