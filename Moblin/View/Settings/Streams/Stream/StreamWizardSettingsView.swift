import SwiftUI

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
    @EnvironmentObject private var model: Model

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
                NavigationLink(destination: StreamWizardAdvancedSettingsView()) {
                    Text("Advanced")
                }
            }
        }
        .navigationTitle("Platform")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
