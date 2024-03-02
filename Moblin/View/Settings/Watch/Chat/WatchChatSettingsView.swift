import SwiftUI

struct WatchChatSettingsView: View {
    @EnvironmentObject var model: Model
    @State var fontSize: Float

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Font size")
                    Slider(
                        value: $fontSize,
                        in: 10 ... 30,
                        step: 1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.watch!.chat.fontSize = fontSize
                            model.store()
                        }
                    )
                    .onChange(of: fontSize) { _ in
                        model.database.watch!.chat.fontSize = fontSize
                    }
                    Text(String(Int(fontSize)))
                        .frame(width: 25)
                }
            } header: {
                Text("General")
            }
        }
        .onDisappear {
            model.store()
        }
        .navigationTitle("Chat")
    }
}
