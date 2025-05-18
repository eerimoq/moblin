import SwiftUI

struct StreamButtonsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var background: Color

    private func onColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        model.database.streamButtonColor = color
        model.updateQuickButtonStates()
    }

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $background, supportsOpacity: false)
                    .onChange(of: background) { _ in
                        onColorChange(color: background)
                    }
                Button {
                    background = defaultStreamButtonColor.color()
                    onColorChange(color: background)
                } label: {
                    HCenter {
                        Text("Reset")
                    }
                }
            } header: {
                Text("Color")
            }
        }
        .navigationTitle("Stream button")
    }
}
