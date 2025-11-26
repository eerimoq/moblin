import SwiftUI

private struct KickSubscriptionsView: View {
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
                    let event = KickPusherSubscriptionEvent(
                        username: alertTestNames.randomElement()!,
                        months: Int.random(in: 1 ... 12)
                    )
                    model.testAlert(alert: .kickSubscription(event: event))
                }
            }
        }
        .navigationTitle("Subscriptions")
    }
}

private struct KickGiftedSubscriptionsView: View {
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
                    let event = KickPusherGiftedSubscriptionsEvent(
                        gifted_usernames: ["1", "2"],
                        gifter_username: alertTestNames.randomElement()!,
                        gifter_total: Int.random(in: 1 ... 50)
                    )
                    model.testAlert(alert: .kickGiftedSubscriptions(event: event))
                }
            }
        }
        .navigationTitle("Gift subscriptions")
    }
}

private struct KickHostsView: View {
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
                    let event = KickPusherStreamHostEvent(
                        host_username: alertTestNames.randomElement()!,
                        number_viewers: Int.random(in: 1 ... 1000)
                    )
                    model.testAlert(alert: .kickHost(event: event))
                }
            }
        }
        .navigationTitle("Hosts")
    }
}

private struct KickRewardsView: View {
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
                    let event = KickPusherRewardRedeemedEvent(
                        reward_title: "Test Reward",
                        username: alertTestNames.randomElement()!,
                        user_input: ""
                    )
                    model.testAlert(alert: .kickReward(event: event))
                }
            }
        }
        .navigationTitle("Rewards")
    }
}

private func formatKickGiftTitle(_ amount: Int, _ comparisonOperator: String) -> String {
    let amountText = countFormatter.format(amount)
    switch SettingsWidgetAlertsCheerBitsAlertOperator(rawValue: comparisonOperator) {
    case .equal:
        return "Kicks \(amountText)"
    case .greaterEqual:
        return "Kicks \(amountText)+"
    default:
        return ""
    }
}

private struct KickGiftView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    let kickGift: SettingsWidgetAlertsKickGiftsAlert
    @Binding var amount: Int
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
            TextEditNavigationView(title: String(localized: "Amount"),
                                   value: String(amount),
                                   onChange: { value in
                                       guard Int(value) != nil else {
                                           return String(localized: "Not a number")
                                       }
                                       return nil
                                   },
                                   onSubmit: { value in
                                       guard let amount = Int(value) else {
                                           return
                                       }
                                       self.amount = amount
                                       kickGift.amount = amount
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
                kickGift.comparisonOperator = comparisonOperator ?? .greaterEqual
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
                    let event = KickPusherKicksGiftedEvent(
                        message: "",
                        sender: KickPusherKickSender(id: 1, username: alertTestNames.randomElement()!),
                        gift: KickPusherKickGift(name: "Kicks", amount: kickGift.amount)
                    )
                    model.testAlert(alert: .kickKicks(event: event))
                }
            }
        }
        .navigationTitle(formatKickGiftTitle(kickGift.amount, kickGift.comparisonOperator.rawValue))
    }
}

private struct KickGiftItemView: View {
    let alert: SettingsWidgetAlertsAlert
    private let kickGift: SettingsWidgetAlertsKickGiftsAlert
    @State private var amount: Int
    @State private var comparisonOperator: String

    init(alert: SettingsWidgetAlertsAlert, kickGift: SettingsWidgetAlertsKickGiftsAlert) {
        self.alert = alert
        self.kickGift = kickGift
        amount = kickGift.amount
        comparisonOperator = kickGift.comparisonOperator.rawValue
    }

    var body: some View {
        HStack {
            DraggableItemPrefixView()
            NavigationLink {
                KickGiftView(
                    alert: alert,
                    kickGift: kickGift,
                    amount: $amount,
                    comparisonOperator: $comparisonOperator
                )
            } label: {
                Text(formatKickGiftTitle(amount, comparisonOperator))
            }
        }
    }
}

private struct KickGiftsView: View {
    @EnvironmentObject var model: Model
    let kick: SettingsWidgetAlertsKick

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(kick.kickGifts) { kickGift in
                        KickGiftItemView(alert: kickGift.alert, kickGift: kickGift)
                    }
                    .onMove { froms, to in
                        kick.kickGifts.move(fromOffsets: froms, toOffset: to)
                        model.updateAlertsSettings()
                    }
                    .onDelete { offsets in
                        kick.kickGifts.remove(atOffsets: offsets)
                        model.updateAlertsSettings()
                    }
                }
                CreateButtonView {
                    let kickGift = SettingsWidgetAlertsKickGiftsAlert()
                    kick.kickGifts.append(kickGift)
                    model.updateAlertsSettings()
                    model.objectWillChange.send()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("The first item that matches kicks amount will be played.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: "an item")
                }
            }
        }
        .navigationTitle("Kicks")
    }
}

struct WidgetAlertsKickSettingsView: View {
    @EnvironmentObject var model: Model
    let kick: SettingsWidgetAlertsKick

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    KickSubscriptionsView(alert: kick.subscriptions)
                } label: {
                    Text("Subscriptions")
                }
                NavigationLink {
                    KickGiftedSubscriptionsView(alert: kick.giftedSubscriptions)
                } label: {
                    Text("Gift subscriptions")
                }
                NavigationLink {
                    KickHostsView(alert: kick.hosts)
                } label: {
                    Text("Hosts")
                }
                NavigationLink {
                    KickRewardsView(alert: kick.rewards)
                } label: {
                    Text("Rewards")
                }
                NavigationLink {
                    KickGiftsView(kick: kick)
                } label: {
                    Text("Kicks")
                }
            }
        }
        .navigationTitle("Kick")
    }
}
