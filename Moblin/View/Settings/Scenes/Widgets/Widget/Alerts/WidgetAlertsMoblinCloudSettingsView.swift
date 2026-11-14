import SwiftUI

private struct MoblinCloudTipsView: View {
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
            AlertMediaView(alert: alert)
            AlertPositionView(alert: alert)
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
                    model.testAlert(alert: .moblinCloudTip(name: alertTestNames.randomElement()!,
                                                           message: "",
                                                           amount: String(Int.random(in: 1 ... 100)),
                                                           currency: "USD"))
                }
            }
        }
        .navigationTitle("Message")
    }
}

struct WidgetAlertsMoblinCloudSettingsView: View {
    let moblinCloud: SettingsWidgetAlertsMoblinCloud

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    MoblinCloudTipsView(alert: moblinCloud.tips)
                } label: {
                    Text("Message")
                }
            }
        }
        .navigationTitle("Moblin Cloud")
    }
}
