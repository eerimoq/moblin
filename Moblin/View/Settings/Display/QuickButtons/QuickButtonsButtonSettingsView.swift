import SwiftUI

struct QuickButtonsButtonSettingsView: View {
    var name: String
    @State var background: Color
    let onChange: (Color) -> Void
    let onSubmit: () -> Void
    @State var page: Int
    let onPage: (Int) -> Void

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
            if isPhone() {
                Section {
                    Picker(selection: $page) {
                        ForEach([1, 2, 3, 4, 5], id: \.self) { page in
                            Text(String(page))
                        }
                    } label: {
                        Text("Page")
                    }
                    .onChange(of: page) { _ in
                        onPage(page)
                    }
                }
            }
        }
        .navigationTitle(name)
    }
}
