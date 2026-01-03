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
                createStreamWizard.presenting = false
                createStreamWizard.presentingSetup = false
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
                    StreamWizardTwitchSettingsView(model: model, createStreamWizard: createStreamWizard)
                } label: {
                    TwitchLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardKickSettingsView(model: model, createStreamWizard: createStreamWizard)
                } label: {
                    KickLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardYouTubeSettingsView(model: model, createStreamWizard: createStreamWizard)
                } label: {
                    YouTubeLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardSoopSettingsView(model: model, createStreamWizard: createStreamWizard)
                } label: {
                    SoopLogoAndNameView()
                }
                NavigationLink {
                    StreamWizardObsSettingsView(model: model, createStreamWizard: createStreamWizard)
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
