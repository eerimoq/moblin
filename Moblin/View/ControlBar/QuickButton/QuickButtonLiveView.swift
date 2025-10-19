import SwiftUI

struct QuickButtonLiveView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @State private var twitchTitle: String?
    @State private var twitchCategory: String?
    @State private var kickTitle: String?
    @State private var kickCategory: String?

    var body: some View {
        Form {
            if stream.twitchLoggedIn {
                Section {
                    TwitchStreamLiveSettingsView(model: model,
                                                 stream: stream,
                                                 title: $twitchTitle,
                                                 category: $twitchCategory)
                } header: {
                    TwitchLogoAndNameView(channel: stream.twitchChannelName)
                }
            }
            if stream.kickLoggedIn {
                Section {
                    KickStreamLiveSettingsView(model: model, stream: stream, title: $kickTitle, category: $kickCategory)
                } header: {
                    KickLogoAndNameView(channel: stream.kickChannelName)
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
        .onAppear {
            loadTwitchStreamInfo(model: model, stream: stream, loggedIn: stream.twitchLoggedIn) {
                twitchTitle = $0
                twitchCategory = $1
            }
            loadKickStreamInfo(model: model, stream: stream, loggedIn: stream.kickLoggedIn) {
                kickTitle = $0
                kickCategory = $1
            }
        }
    }
}
