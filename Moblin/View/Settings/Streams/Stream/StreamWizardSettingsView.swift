import SwiftUI

struct WizardNextButtonView: View {
    var body: some View {
        HStack {
            Spacer()
            Text("Next")
                .foregroundColor(.accentColor)
            Spacer()
        }
    }
}

struct WizardSkipButtonView: View {
    var body: some View {
        HStack {
            Spacer()
            Text("Skip")
                .foregroundColor(.accentColor)
            Spacer()
        }
    }
}

struct CreateStreamWizardToolbar: ToolbarContent {
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    createStreamWizard.isPresenting = false
                    createStreamWizard.isPresentingSetup = false
                } label: {
                    Text("Close")
                }
            }
        }
    }
}

struct StreamWizardSettingsView: View {
    var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardTwitchSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("Twitch")
                }
                NavigationLink {
                    StreamWizardKickSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("Kick")
                }
                NavigationLink {
                    StreamWizardYouTubeSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("YouTube")
                }
                NavigationLink {
                    StreamWizardAfreecaTvSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("AfreecaTV")
                }
                NavigationLink {
                    StreamWizardObsSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    Text("OBS")
                }
            } header: {
                Text("Platform to stream to")
            }
            Section {
                NavigationLink {
                    StreamWizardCustomSettingsView(createStreamWizard: createStreamWizard)
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
