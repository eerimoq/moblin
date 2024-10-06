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
    @EnvironmentObject var model: Model

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button(action: {
                    model.isPresentingWizard = false
                    model.isPresentingSetupWizard = false
                }, label: {
                    Text("Close")
                })
            }
        }
    }
}

struct StreamWizardSettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StreamWizardTwitchSettingsView()
                } label: {
                    Text("Twitch")
                }
                NavigationLink {
                    StreamWizardKickSettingsView()
                } label: {
                    Text("Kick")
                }
                NavigationLink {
                    StreamWizardYouTubeSettingsView()
                } label: {
                    Text("YouTube")
                }
                NavigationLink {
                    StreamWizardAfreecaTvSettingsView()
                } label: {
                    Text("AfreecaTV")
                }
            } header: {
                Text("Platform to stream to")
            }
            Section {
                NavigationLink {
                    StreamWizardCustomSettingsView()
                } label: {
                    Text("Custom")
                }
            } footer: {
                Text("For advanced users or if your platform is not in the list above.")
            }
        }
        .navigationTitle("Create stream wizard")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
