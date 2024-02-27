import SwiftUI

struct StreamButtonsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var background: Color

    private func onColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        model.database.streamButtonColor = color
        model.updateButtonStates()
    }

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $background, supportsOpacity: false)
                    .onChange(of: background) { _ in
                        onColorChange(color: background)
                    }
                    .onDisappear {
                        model.store()
                    }
                Button(action: {
                    background = defaultStreamButtonColor.color()
                    onColorChange(color: background)
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
