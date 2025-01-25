import SwiftUI

struct QuickButtonsButtonSettingsView: View {
    var name: String
    @State var background: Color
    let onChange: (Color) -> Void
    let onSubmit: () -> Void

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $background, supportsOpacity: false)
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
                    HCenter {
                        Text("Reset")
                    }
                })
            } header: {
                Text("Color")
            }
        }
        .navigationTitle(name)
    }
}
