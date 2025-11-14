import SwiftUI

private struct SpeechToTextStringView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var alert: SettingsWidgetAlertsAlert
    let string: SettingsWidgetAlertsSpeechToTextString
    @State var text: String

    private func onSubmit(value: String) {
        string.string = value
        text = value
        model.updateAlertsSettings()
    }

    var body: some View {
        NavigationLink {
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
                Section {
                    TextEditNavigationView(title: String(localized: "String"),
                                           value: text,
                                           onSubmit: onSubmit)
                } footer: {
                    Text("Trigger by saying '\(text)'.")
                }
                AlertMediaView(alert: alert, imageId: alert.imageId, soundId: alert.soundId)
                AlertPositionView(alert: alert, positionType: alert.positionType)
                Section {
                    TextButtonView("Test") {
                        model.testAlert(alert: .speechToTextString(string.id))
                    }
                }
            }
            .navigationTitle("String")
        } label: {
            Text(text)
        }
    }
}

struct WidgetAlertsSpeechToTextSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var speechToText: SettingsWidgetAlertsSpeechToText

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(speechToText.strings) { string in
                        SpeechToTextStringView(alert: string.alert, string: string, text: string.string)
                    }
                    .onDelete { indexes in
                        speechToText.strings.remove(atOffsets: indexes)
                        model.updateAlertsSettings()
                    }
                }
                CreateButtonView {
                    let string = SettingsWidgetAlertsSpeechToTextString()
                    speechToText.strings.append(string)
                    model.fixAlertMedias()
                    model.updateAlertsSettings()
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Trigger alerts when you say something.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a string"))
                }
            }
        }
        .navigationTitle("Speech to text")
    }
}
