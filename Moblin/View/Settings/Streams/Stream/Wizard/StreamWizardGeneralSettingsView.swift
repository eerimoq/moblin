import SwiftUI

struct StreamWizardGeneralSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.wizardChatBttv, label: {
                    Text("BTTV emotes")
                })
                Toggle(isOn: $model.wizardChatFfz, label: {
                    Text("FFZ emotes")
                })
                Toggle(isOn: $model.wizardChatSeventv, label: {
                    Text("7TV emotes")
                })
            } header: {
                Text("Chat")
            }
            Section {
                NavigationLink(destination: StreamWizardSummarySettingsView()) {
                    WizardNextButtonView()
                }
            }
        }
        .navigationTitle("General")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
