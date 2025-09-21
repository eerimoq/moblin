import SwiftUI

struct KickChatNotificationsSettingsView: View {
    @ObservedObject var stream: SettingsStream
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowSubscriptionsChat)
                }
                HStack {
                    Text("Gifted Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowGiftedSubscriptionsChat)
                }
                HStack {
                    Text("Rewards")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowRewardsChat)
                }
                HStack {
                    Text("Hosts")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowHostsChat)
                }
                HStack {
                    Text("Bans/Timeouts")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowBansChat)
                }
                HStack {
                    Text("Kicks (Bits)")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowKicksChat)
                }
                TextEditNavigationView(
                    title: "Min kicks for chat",
                    value: String(stream.kickMinimumKickAmountForChat),
                    onSubmit: { value in
                        stream.kickMinimumKickAmountForChat = Int(value) ?? 0
                    },
                    keyboardType: .numberPad
                )
            } footer: {
                Text("Enable chat notifications for Kick events.")
            }
        }
        .navigationTitle("Chat Notifications")
    }
}
