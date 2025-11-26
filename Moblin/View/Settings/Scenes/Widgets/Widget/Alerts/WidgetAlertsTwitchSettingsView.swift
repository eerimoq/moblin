import SwiftUI

private struct TwitchFollowsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    alert.enabled
                }, set: { value in
                    alert.enabled = value
                    model.updateAlertsSettings()
                })) {
                    Text("Enabled")
                }
            }
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
            AlertPositionView(alert: alert, positionType: alert.positionType)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(
                alert: alert,
                fontSize: Float(alert.fontSize),
                fontDesign: alert.fontDesign,
                fontWeight: alert.fontWeight
            )
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.textToSpeechDelay)
            Section {
                TextButtonView("Test") {
                    let event = TwitchEventSubNotificationChannelFollowEvent(
                        user_name: alertTestNames.randomElement()!
                    )
                    model.testAlert(alert: .twitchFollow(event))
                }
            }
        }
        .navigationTitle("Follows")
    }
}

private struct TwitchSubscriptionsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    alert.enabled
                }, set: { value in
                    alert.enabled = value
                    model.updateAlertsSettings()
                })) {
                    Text("Enabled")
                }
            }
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
            AlertPositionView(alert: alert, positionType: alert.positionType)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(
                alert: alert,
                fontSize: Float(alert.fontSize),
                fontDesign: alert.fontDesign,
                fontWeight: alert.fontWeight
            )
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.textToSpeechDelay)
            Section {
                TextButtonView("Test") {
                    let event = TwitchEventSubNotificationChannelSubscribeEvent(
                        user_name: alertTestNames.randomElement()!,
                        tier: "2000",
                        is_gift: false
                    )
                    model.testAlert(alert: .twitchSubscribe(event))
                }
            }
        }
        .navigationTitle("Subscriptions")
    }
}

private struct TwitchRaidsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    alert.enabled
                }, set: { value in
                    alert.enabled = value
                    model.updateAlertsSettings()
                })) {
                    Text("Enabled")
                }
            }
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
            AlertPositionView(alert: alert, positionType: alert.positionType)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(
                alert: alert,
                fontSize: Float(alert.fontSize),
                fontDesign: alert.fontDesign,
                fontWeight: alert.fontWeight
            )
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.textToSpeechDelay)
            Section {
                TextButtonView("Test") {
                    let event = TwitchEventSubChannelRaidEvent(
                        from_broadcaster_user_name: alertTestNames.randomElement()!,
                        viewers: .random(in: 1 ..< 1000)
                    )
                    model.testAlert(alert: .twitchRaid(event))
                }
            }
        }
        .navigationTitle("Raids")
    }
}

private func formatTitle(_ bits: Int, _ comparisonOperator: String) -> String {
    let bitsText = countFormatter.format(bits)
    switch SettingsWidgetAlertsCheerBitsAlertOperator(rawValue: comparisonOperator) {
    case .equal:
        if bits == 1 {
            return "Cheer \(bitsText) bit"
        } else {
            return "Cheer \(bitsText) bits"
        }
    case .greaterEqual:
        return "Cheer \(bitsText)+ bits"
    default:
        return ""
    }
}

private struct TwitchCheerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    let cheerBit: SettingsWidgetAlertsCheerBitsAlert
    @Binding var bits: Int
    @Binding var comparisonOperator: String

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    alert.enabled
                }, set: { value in
                    alert.enabled = value
                    model.updateAlertsSettings()
                })) {
                    Text("Enabled")
                }
            }
            TextEditNavigationView(title: String(localized: "Bits"),
                                   value: String(bits),
                                   onChange: { value in
                                       guard Int(value) != nil else {
                                           return String(localized: "Not a number")
                                       }
                                       return nil
                                   },
                                   onSubmit: { value in
                                       guard let bits = Int(value) else {
                                           return
                                       }
                                       self.bits = bits
                                       cheerBit.bits = bits
                                       model.updateAlertsSettings()
                                   },
                                   keyboardType: .numbersAndPunctuation)
            Picker("Comparison", selection: $comparisonOperator) {
                ForEach(cheerBitsAlertOperators, id: \.self) {
                    Text($0)
                }
            }
            .onChange(of: comparisonOperator) { _ in
                let comparisonOperator = SettingsWidgetAlertsCheerBitsAlertOperator(rawValue: comparisonOperator)
                cheerBit.comparisonOperator = comparisonOperator ?? .greaterEqual
                model.updateAlertsSettings()
            }
            AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
            AlertPositionView(alert: alert, positionType: alert.positionType)
            AlertColorsView(
                alert: alert,
                textColor: alert.textColor.color(),
                accentColor: alert.accentColor.color()
            )
            AlertFontView(
                alert: alert,
                fontSize: Float(alert.fontSize),
                fontDesign: alert.fontDesign,
                fontWeight: alert.fontWeight
            )
            AlertTextToSpeechView(alert: alert, ttsDelay: alert.textToSpeechDelay)
            Section {
                TextButtonView("Test") {
                    let event = TwitchEventSubChannelCheerEvent(
                        user_name: alertTestNames.randomElement()!,
                        message: "A test message!",
                        bits: cheerBit.bits
                    )
                    model.testAlert(alert: .twitchCheer(event))
                }
            }
        }
        .navigationTitle(formatTitle(cheerBit.bits, cheerBit.comparisonOperator.rawValue))
    }
}

private struct TwitchCheerBitsItemView: View {
    let alert: SettingsWidgetAlertsAlert
    private let cheerBit: SettingsWidgetAlertsCheerBitsAlert
    @State private var bits: Int
    @State private var comparisonOperator: String

    init(alert: SettingsWidgetAlertsAlert, cheerBit: SettingsWidgetAlertsCheerBitsAlert) {
        self.alert = alert
        self.cheerBit = cheerBit
        bits = cheerBit.bits
        comparisonOperator = cheerBit.comparisonOperator.rawValue
    }

    var body: some View {
        HStack {
            DraggableItemPrefixView()
            NavigationLink {
                TwitchCheerView(
                    alert: alert,
                    cheerBit: cheerBit,
                    bits: $bits,
                    comparisonOperator: $comparisonOperator
                )
            } label: {
                Text(formatTitle(bits, comparisonOperator))
            }
        }
    }
}

private struct TwitchCheerBitsView: View {
    @EnvironmentObject var model: Model
    let twitch: SettingsWidgetAlertsTwitch

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(twitch.cheerBits) { cheerBit in
                        TwitchCheerBitsItemView(alert: cheerBit.alert, cheerBit: cheerBit)
                    }
                    .onMove { froms, to in
                        twitch.cheerBits.move(fromOffsets: froms, toOffset: to)
                        model.updateAlertsSettings()
                    }
                    .onDelete { offsets in
                        twitch.cheerBits.remove(atOffsets: offsets)
                        model.updateAlertsSettings()
                    }
                }
                CreateButtonView {
                    let cheerBits = SettingsWidgetAlertsCheerBitsAlert()
                    twitch.cheerBits.append(cheerBits)
                    model.updateAlertsSettings()
                    model.objectWillChange.send()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("The first item that matches cheered bits will be played.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: "an item")
                }
            }
        }
        .navigationTitle("Cheers")
    }
}

private struct TwitchRewardView: View {
    @EnvironmentObject var model: Model
    let reward: SettingsStreamTwitchReward

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    reward.alert.enabled
                }, set: { value in
                    reward.alert.enabled = value
                    model.updateAlertsSettings()
                })) {
                    Text("Enabled")
                }
            }
            AlertMediaView(alert: reward.alert, imageId: reward.alert.imageId, soundId: reward.alert.soundId)
        }
        .navigationTitle(reward.title)
    }
}

private struct TwitchRewardsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            if model.stream.twitchRewards.isEmpty {
                Text("No rewards found")
            } else {
                ForEach(model.stream.twitchRewards) { reward in
                    NavigationLink {
                        TwitchRewardView(reward: reward)
                    } label: {
                        Text(reward.title)
                    }
                }
            }
        }
        .onAppear {
            model.fetchTwitchRewards()
        }
        .navigationTitle("Rewards")
    }
}

struct WidgetAlertsTwitchSettingsView: View {
    @EnvironmentObject var model: Model
    let twitch: SettingsWidgetAlertsTwitch

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    TwitchFollowsView(alert: twitch.follows)
                } label: {
                    Text("Follows")
                }
                NavigationLink {
                    TwitchSubscriptionsView(alert: twitch.subscriptions)
                } label: {
                    Text("Subscriptions")
                }
                NavigationLink {
                    TwitchRaidsView(alert: twitch.raids)
                } label: {
                    Text("Raids")
                }
                NavigationLink {
                    TwitchCheerBitsView(twitch: twitch)
                } label: {
                    Text("Cheers")
                }
                if model.database.debug.twitchRewards {
                    NavigationLink {
                        TwitchRewardsView()
                    } label: {
                        Text("Rewards")
                    }
                }
            }
        }
        .navigationTitle("Twitch")
    }
}
