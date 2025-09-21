import SwiftUI

struct TwitchToastNotificationsSettingsView: View {
    @ObservedObject var stream: SettingsStream
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Follows")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowFollowsToast)
                }
                HStack {
                    Text("Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowSubscriptionsToast)
                }
                HStack {
                    Text("Gifted Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowSubscriptionGiftsToast)
                }
                HStack {
                    Text("Resubscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowResubscriptionsToast)
                }
                HStack {
                    Text("Rewards")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowRewardsToast)
                }
                HStack {
                    Text("Raids")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowRaidsToast)
                }
                HStack {
                    Text("Cheers (Bits)")
                    Spacer()
                    Toggle("", isOn: $stream.twitchShowCheersToast)
                }
                TextEditNavigationView(
                    title: "Min bits for toast",
                    value: String(stream.twitchMinimumBitsAmountForToast),
                    onSubmit: { value in
                        stream.twitchMinimumBitsAmountForToast = Int(value) ?? 0
                    },
                    keyboardType: .numberPad
                )
            } footer: {
                Text("Enable toast notifications for Twitch events.")
            }
        }
        .navigationTitle("Toast Notifications")
    }
}
