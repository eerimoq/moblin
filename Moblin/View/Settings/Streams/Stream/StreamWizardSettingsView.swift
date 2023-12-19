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

struct CreateStreamWizardToolbar: ToolbarContent {
    @EnvironmentObject var model: Model

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button(action: {
                    model.isPresentingWizard = false
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
                NavigationLink(destination: StreamWizardTwitchSettingsView()) {
                    Text("Twitch")
                }
                NavigationLink(destination: StreamWizardKickSettingsView()) {
                    Text("Kick")
                }
            } header: {
                Text("Platform to stream to")
            }
            Section {
                NavigationLink(destination: StreamWizardCustomSettingsView()) {
                    Text("Custom")
                }
            }
        }
        .navigationTitle("Create stream wizard")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
