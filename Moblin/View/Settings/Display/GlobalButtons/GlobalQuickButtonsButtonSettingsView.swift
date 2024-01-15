import SwiftUI

struct GlobalQuickButtonsButtonSettingsView: View {
    var name: String
    @State var background: Color
    let onChange: (Color) -> Void
    let onSubmit: () -> Void

    var body: some View {
        Form {
            Section {
                ColorPicker("Color", selection: $background, supportsOpacity: false)
                    .onChange(of: background) { _ in
                        onChange(background)
                    }
                    .onDisappear {
                        onSubmit()
                    }
                Button(action: {
                    background = defaultQuickButtonColor.color()
                    onChange(background)
                    onSubmit()
                }, label: {
                    HStack {
                        Spacer()
                        Text("Reset")
                        Spacer()
                    }
                })
            } header: {
                Text("Background")
            }
        }
        .navigationTitle(name)
        .toolbar {
            SettingsToolbar()
        }
    }
}
