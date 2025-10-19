import SwiftUI

struct QuickButtonLiveView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            if stream.twitchLoggedIn {
                Section {
                    TwitchStreamLiveSettingsView(model: model, stream: model.stream)
                } header: {
                    TwitchLogoAndNameView()
                }
            }
            if stream.kickLoggedIn {
                Section {
                    KickStreamLiveSettingsView(model: model, stream: model.stream)
                } header: {
                    KickLogoAndNameView()
                }
            }
            if !stream.goLiveNotificationDiscordWebhookUrl.isEmpty {
                Section {
                    NavigationLink {
                        Form {
                            GoLiveNotificationDiscordTextSettingsView(stream: stream)
                        }
                        .navigationTitle("Discord")
                    } label: {
                        DiscordLogoAndNameView()
                    }
                    Button {
                        model.sendGoLiveNotification()
                    } label: {
                        HCenter {
                            Text("Send")
                        }
                    }
                    .disabled(!model.isGoLiveNotificationConfigured())
                } header: {
                    Text("Go live notification")
                }
            }
            Section {
                NavigationLink {
                    StreamSettingsView(database: model.database, stream: stream)
                } label: {
                    Label("Stream", systemImage: "dot.radiowaves.left.and.right")
                }
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle("Stream")
    }
}
