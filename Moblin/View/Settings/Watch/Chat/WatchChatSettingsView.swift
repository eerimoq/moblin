import SwiftUI

struct WatchChatSettingsView: View {
    @EnvironmentObject var model: Model
    @State var fontSize: Float
    @State var notificationRate: Int
    
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
                            model.database.watch.chat.fontSize = fontSize
                            model.sendSettingsToWatch()
                        }
                    )
                    .onChange(of: fontSize) { _ in
                        model.database.watch.chat.fontSize = fontSize
                    }
                    Text(String(Int(fontSize)))
                        .frame(width: 25)
                }
                Toggle(isOn: Binding(get: {
                    model.database.watch.chat.timestampEnabled!
                }, set: { value in
                    model.database.watch.chat.timestampEnabled = value
                    model.sendSettingsToWatch()
                })) {
                    Text("Timestamp")
                }
                Toggle(isOn: Binding(get: {
                    model.database.watch.chat.badges!
                }, set: { value in
                    model.database.watch.chat.badges = value
                    model.sendSettingsToWatch()
                })) {
                    Text("Badges")
                }
                Toggle(isOn: Binding(get: {
                    model.database.watch.chat.notificationOnMessage!
                }, set: { value in
                    model.database.watch.chat.notificationOnMessage = value
                    model.sendSettingsToWatch()
                })) {
                    Text("Notification on message")
                }
                HStack {
                    Text("Notification rate")
                    Spacer()
                    TextField("", value: $notificationRate, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: notificationRate) { newValue in
                            model.database.watch.chat.notificationRate = Int(newValue)
                            model.sendSettingsToWatch()
                        }
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
