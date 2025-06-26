import SwiftUI

struct StreamWizardChatSettingsView: View {
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $createStreamWizard.chatBttv, label: {
                    Text("BTTV emotes")
                })
                Toggle(isOn: $createStreamWizard.chatFfz, label: {
                    Text("FFZ emotes")
                })
                Toggle(isOn: $createStreamWizard.chatSeventv, label: {
                    Text("7TV emotes")
                })
            }
            Section {
                if createStreamWizard.networkSetup == .direct {
                    NavigationLink {
                        StreamWizardSummarySettingsView(createStreamWizard: createStreamWizard)
                    } label: {
                        WizardNextButtonView()
                    }
                } else {
                    NavigationLink {
                        StreamWizardObsRemoteControlSettingsView(createStreamWizard: createStreamWizard)
                    } label: {
                        WizardNextButtonView()
                    }
                }
            }
        }
        .navigationTitle("Chat")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
