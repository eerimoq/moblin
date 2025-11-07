import SwiftUI

struct WizardNextButtonView: View {
    var body: some View {
        HCenter {
            Text("Next")
                .foregroundStyle(Color.accentColor)
        }
    }
}

struct WizardSkipButtonView: View {
    var body: some View {
        HCenter {
            Text("Skip")
                .foregroundStyle(Color.accentColor)
        }
    }
}

struct CreateStreamWizardToolbar: ToolbarContent {
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                createStreamWizard.isPresenting = false
                createStreamWizard.isPresentingSetup = false
            } label: {
                Image(systemName: "xmark")
            }
        }
    }
}

struct StreamWizardSettingsView: View {
    let model: Model
    let createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardTwitchSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    TwitchLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardKickSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    KickLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardYouTubeSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    YouTubeLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardSoopSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    SoopLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardObsSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    ObsLogoAndNameView()
                }
            } header: {
                Text("Platform to stream to")
            }
            Section {
                NavigationLink {
                    StreamWizardCustomSettingsView(model: model, createStreamWizard: createStreamWizard)
                } label: {
                    Text("Custom")
                }
            } footer: {
                Text("For advanced users or if your platform is not in the list above.")
            }
        }
        .navigationTitle("Create stream wizard")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
