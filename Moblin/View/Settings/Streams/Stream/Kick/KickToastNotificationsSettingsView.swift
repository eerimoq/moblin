import SwiftUI

struct KickToastNotificationsSettingsView: View {
    @ObservedObject var stream: SettingsStream
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowSubscriptionsToast)
                }
                HStack {
                    Text("Gifted Subscriptions")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowGiftedSubscriptionsToast)
                }
                HStack {
                    Text("Rewards")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowRewardsToast)
                }
                HStack {
                    Text("Hosts")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowHostsToast)
                }
                HStack {
                    Text("Bans/Timeouts")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowBansToast)
                }
                HStack {
                    Text("Kicks (Bits)")
                    Spacer()
                    Toggle("", isOn: $stream.kickShowKicksToast)
                }
                TextEditNavigationView(
                    title: "Min kicks for toast",
                    value: String(stream.kickMinimumKickAmountForToast),
                    onSubmit: { value in
                        stream.kickMinimumKickAmountForToast = Int(value) ?? 0
                    },
                    keyboardType: .numberPad
                )
            } footer: {
                Text("Enable toast notifications for Kick events.")
            }
        }
        .navigationTitle("Toast Notifications")
    }
}
