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
        VStack(alignment: .leading) {
            Text("Where do you want to stream to?")
                .font(.title2)
                .padding()
            Form {
                Section {
                    NavigationLink(destination: StreamWizardTwitchSettingsView()) {
                        Text("Twitch")
                    }
                    NavigationLink(destination: StreamWizardKickSettingsView()) {
                        Text("Kick")
                    }
                }
                Section {
                    Button {
                        model.database.streams.append(SettingsStream(name: String(localized: "My stream")))
                        model.store()
                        model.isPresentingWizard = false
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create manually")
                            Spacer()
                        }
                    }
                }
            }
            Spacer()
        }
        .navigationTitle("Platform")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
