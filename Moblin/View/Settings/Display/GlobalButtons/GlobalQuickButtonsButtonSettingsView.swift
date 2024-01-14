import SwiftUI

struct GlobalQuickButtonsButtonSettingsView: View {
    @EnvironmentObject var model: Model
    var name: String
    @State var background: Color
    let onChange: (Color) -> Void
    let onSubmit: () -> Void

    var body: some View {
        Form {
            ColorPicker("Background", selection: $background, supportsOpacity: false)
                .onChange(of: background) { _ in
                    onChange(background)
                }
                .onDisappear {
                    onSubmit()
                }
        }
        .navigationTitle(name)
        .toolbar {
            SettingsToolbar()
        }
    }
}
