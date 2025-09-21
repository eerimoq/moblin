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

private struct EventToggleRow: View {
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

private struct KickAmountToggleRow: View {
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
                        Text("Kicks (Tips)")
                        Spacer()
                        Image(systemName: showingAmountSettings ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                })
                .buttonStyle(PlainButtonStyle())
                ToggleDot(binding: $stream.kickShowKicksToast)
                ToggleDot(binding: $stream.kickShowKicksChat)
            }
            .padding(.vertical, 6)
            if showingAmountSettings {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    HStack {
                        Text("Min amount for toast:")
                            .font(.caption)
                        Spacer()
                        TextField("0", value: Binding(
                            get: { stream.kickMinimumKickAmountForToast },
                            set: { stream.kickMinimumKickAmountForToast = $0 }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.numberPad)
                    }
                    .padding(.horizontal)
                    HStack {
                        Text("Min amount for chat:")
                            .font(.caption)
                        Spacer()
                        TextField("0", value: Binding(
                            get: { stream.kickMinimumKickAmountForChat },
                            set: { stream.kickMinimumKickAmountForChat = $0 }
                        ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .keyboardType(.numberPad)
                    }
                    .padding(.horizontal)
                    Text("Set minimum tip amounts (0 = show all tips)")
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

struct KickNotificationsSettingsView: View {
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
                    EventToggleRow(
                        title: "Subscriptions",
                        toastBinding: $stream.kickShowSubscriptionsToast,
                        chatBinding: $stream.kickShowSubscriptionsChat
                    )
                    EventToggleRow(
                        title: "Gifted Subscriptions",
                        toastBinding: $stream.kickShowGiftedSubscriptionsToast,
                        chatBinding: $stream.kickShowGiftedSubscriptionsChat
                    )
                    EventToggleRow(
                        title: "Rewards",
                        toastBinding: $stream.kickShowRewardsToast,
                        chatBinding: $stream.kickShowRewardsChat
                    )
                    EventToggleRow(
                        title: "Hosts",
                        toastBinding: $stream.kickShowHostsToast,
                        chatBinding: $stream.kickShowHostsChat
                    )
                    EventToggleRow(
                        title: "Bans/Timeouts",
                        toastBinding: $stream.kickShowBansToast,
                        chatBinding: $stream.kickShowBansChat
                    )
                    KickAmountToggleRow(stream: stream)
                }
            } footer: {
                Text("Tap circles to enable/disable notifications for each event type.")
            }
        }
        .navigationTitle("Notifications")
    }
}
