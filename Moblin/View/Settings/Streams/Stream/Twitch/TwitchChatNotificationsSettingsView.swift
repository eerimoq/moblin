import SwiftUI

struct TwitchChatNotificationsSettingsView: View {
    @ObservedObject var stream: SettingsStream
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Follows")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowFollowsChat)
                }
                HStack {
                    Text("Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowSubscriptionsChat)
                }
                HStack {
                    Text("Gifted Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowSubscriptionGiftsChat)
                }
                HStack {
                    Text("Resubscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowResubscriptionsChat)
                }
                HStack {
                    Text("Rewards")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowRewardsChat)
                }
                HStack {
                    Text("Raids")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowRaidsChat)
                }
                HStack {
                    Text("Cheers (Bits)")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowCheersChat)
                }
                TextEditNavigationView(
                    title: "Min bits for chat",
                    value: String(stream.twitchMinimumBitsAmountForChat),
                    onSubmit: { value in
                        stream.twitchMinimumBitsAmountForChat = Int(value) ?? 0
                    },
                    keyboardType: .numberPad
                )
            } footer: {
                Text("Enable chat notifications for Twitch events.")
            }
        }
        .navigationTitle("Chat Notifications")
    }
}
