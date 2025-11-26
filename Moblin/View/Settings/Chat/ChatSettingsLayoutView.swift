import SwiftUI

private let sliderValuePercentageWidth = 60.0

struct ChatSettingsLayoutView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: SettingsChat

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    HStack {
                        Text("Height")
                        Slider(
                            value: $chat.height,
                            in: 0.2 ... 1.0,
                            step: 0.01,
                            onEditingChanged: { begin in
                                guard !begin else {
                                    return
                                }
                                model.reloadChatMessages()
                            }
                        )
                        Text("\(Int(100 * chat.height))%")
                            .frame(width: sliderValuePercentageWidth)
                    }
                    HStack {
                        Text("Width")
                        Slider(
                            value: $chat.width,
                            in: 0.2 ... 1.0,
                            step: 0.01,
                            onEditingChanged: { begin in
                                guard !begin else {
                                    return
                                }
                                model.reloadChatMessages()
                            }
                        )
                        Text("\(Int(100 * chat.width))%")
                            .frame(width: sliderValuePercentageWidth)
                    }
                    HStack {
                        Text("Bottom")
                        Slider(
                            value: $chat.bottomPoints,
                            in: 0.0 ... 200.0,
                            step: 5,
                            onEditingChanged: { begin in
                                guard !begin else {
                                    return
                                }
                                model.reloadChatMessages()
                            }
                        )
                        Text("\(Int(chat.bottomPoints)) pts")
                            .frame(width: sliderValuePercentageWidth)
                    }
                    if model.database.showAllSettings {
                        Toggle("New messages at top", isOn: $chat.newMessagesAtTop)
                        Toggle("Mirrored", isOn: $chat.mirrored)
                    }
                }
            }
            .navigationTitle("Layout")
        } label: {
            Text("Layout")
        }
    }
}
