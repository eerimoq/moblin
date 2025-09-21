import SwiftUI

private struct ToggleDot: View {
    let binding: Binding<Bool>
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: binding.wrappedValue ? "circle.fill" : "circle")
                .foregroundColor(binding.wrappedValue ? .blue : .gray)
                .font(.title3)
                .onTapGesture {
                    binding.wrappedValue.toggle()
                }
            Spacer()
        }
        .frame(width: 50)
    }
}

private struct TwitchEventToggleRow: View {
    let title: String
    let toastBinding: Binding<Bool>
    let chatBinding: Binding<Bool>
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            ToggleDot(binding: toastBinding)
            ToggleDot(binding: chatBinding)
        }
        .padding(.vertical, 6)
    }
}

private struct TwitchCheersAmountToggleRow: View {
    @ObservedObject var stream: SettingsStream
    @State private var showingAmountSettings = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingAmountSettings.toggle()
                    }
                }, label: {
                    HStack {
                        Text("Cheers (Bits)")
                        Spacer()
                        Image(systemName: showingAmountSettings ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                })
                .buttonStyle(PlainButtonStyle())
                ToggleDot(binding: $stream.twitchShowCheersToast)
                ToggleDot(binding: $stream.twitchShowCheersChat)
            }
            .padding(.vertical, 6)
            if showingAmountSettings {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    HStack {
                        Text("Min bits for toast:")
                            .font(.caption)
                        Spacer()
                        TextField("0", value: Binding(
                            get: { stream.twitchMinimumBitsAmountForToast },
                            set: { stream.twitchMinimumBitsAmountForToast = $0 }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.numberPad)
                    }
                    .padding(.horizontal)
                    HStack {
                        Text("Min bits for chat:")
                            .font(.caption)
                        Spacer()
                        TextField("0", value: Binding(
                            get: { stream.twitchMinimumBitsAmountForChat },
                            set: { stream.twitchMinimumBitsAmountForChat = $0 }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.numberPad)
                    }
                    .padding(.horizontal)
                    Text("Set minimum bits amounts (0 = show all cheers)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
    }
}

struct TwitchNotificationsSettingsView: View {
    @ObservedObject var stream: SettingsStream
    var body: some View {
        Form {
            Section {
                VStack(spacing: 4) {
                    HStack {
                        Text("Event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Toast")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                        Text("Chat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    .padding(.vertical, 4)
                    TwitchEventToggleRow(
                        title: "Follows",
                        toastBinding: $stream.twitchShowFollowsToast,
                        chatBinding: $stream.twitchShowFollowsChat
                    )
                    TwitchEventToggleRow(
                        title: "Subscriptions",
                        toastBinding: $stream.twitchShowSubscriptionsToast,
                        chatBinding: $stream.twitchShowSubscriptionsChat
                    )
                    TwitchEventToggleRow(
                        title: "Gifted Subscriptions",
                        toastBinding: $stream.twitchShowSubscriptionGiftsToast,
                        chatBinding: $stream.twitchShowSubscriptionGiftsChat
                    )
                    TwitchEventToggleRow(
                        title: "Resubscriptions",
                        toastBinding: $stream.twitchShowResubscriptionsToast,
                        chatBinding: $stream.twitchShowResubscriptionsChat
                    )
                    TwitchEventToggleRow(
                        title: "Rewards",
                        toastBinding: $stream.twitchShowRewardsToast,
                        chatBinding: $stream.twitchShowRewardsChat
                    )
                    TwitchEventToggleRow(
                        title: "Raids",
                        toastBinding: $stream.twitchShowRaidsToast,
                        chatBinding: $stream.twitchShowRaidsChat
                    )
                    TwitchCheersAmountToggleRow(stream: stream)
                }
            } footer: {
                Text("Tap circles to enable/disable notifications for each event type.")
            }
        }
        .navigationTitle("Notifications")
    }
}
