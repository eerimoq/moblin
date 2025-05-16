import SwiftUI

private struct A: View {
    @State var background: Color
    let onChange: (Color) -> Void

    var body: some View {
        ColorPicker("Background", selection: $background, supportsOpacity: false)
            .onChange(of: background) { _ in
                onChange(background)
            }
    }
}

struct QuickButtonsButtonSettingsView: View {
    @ObservedObject var button: SettingsQuickButton
    let onChange: (Color) -> Void
    let onSubmit: () -> Void
    let onPage: (Int) -> Void

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $button.color, supportsOpacity: false)
                    .onChange(of: button.color) { _ in
                        onChange(button.color)
                    }
                    .onDisappear {
                        onSubmit()
                    }
                Button(action: {
                    button.color = defaultQuickButtonColor.color()
                    onChange(button.color)
                    onSubmit()
                }, label: {
                    HCenter {
                        Text("Reset")
                    }
                })
            } header: {
                Text("Color")
            }
            Section {
                Picker(selection: $button.page) {
                    ForEach([1, 2, 3, 4, 5], id: \.self) { page in
                        Text(String(page))
                            .tag(page as Int?)
                    }
                } label: {
                    Text("Page")
                }
                .onChange(of: button.page) { _ in
                    onPage(button.page!)
                }
            }
        }
        .navigationTitle(button.name)
    }
}
