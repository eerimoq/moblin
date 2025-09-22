import SwiftUI

struct WatchChatSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var chat: WatchSettingsChat

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Font size")
                    Slider(
                        value: $chat.fontSize,
                        in: 10 ... 30,
                        step: 1,
                        label: {
                            EmptyView()
                        },
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.sendSettingsToWatch()
                        }
                    )
                    Text(String(Int(chat.fontSize)))
                        .frame(width: 25)
                }
                Toggle("Timestamp", isOn: $chat.timestampEnabled)
                    .onChange(of: chat.timestampEnabled) { _ in
                        model.sendSettingsToWatch()
                    }
                Toggle("Badges", isOn: $chat.badges)
                    .onChange(of: chat.badges) { _ in
                        model.sendSettingsToWatch()
                    }
                Toggle("Notification on message", isOn: $chat.notificationOnMessage)
                    .onChange(of: chat.notificationOnMessage) { _ in
                        model.sendSettingsToWatch()
                    }
                Picker("Notification rate", selection: $chat.notificationRate) {
                    ForEach([60, 30, 15, 5, 1], id: \.self) { rate in
                        Text("\(rate) s")
                    }
                }
                .onChange(of: chat.notificationRate) { _ in
                    model.sendSettingsToWatch()
                }
            } header: {
                Text("General")
            }
        }
        .onDisappear {
            model.sendSettingsToWatch()
        }
        .navigationTitle("Chat")
    }
}
