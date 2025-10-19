import SwiftUI

struct QuickButtonLiveView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @State private var twitchTitle: String?
    @State private var twitchCategory: String?
    @State private var kickTitle: String?
    @State private var kickCategory: String?

    private func loadTwitchStreamInfo() {
        twitchTitle = nil
        twitchCategory = nil
        guard stream.twitchLoggedIn else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            model.getTwitchChannelInformation(stream: stream) { info in
                twitchTitle = info.title
                twitchCategory = info.game_name
            }
        }
    }

    private func loadKickStreamInfo() {
        kickTitle = nil
        kickCategory = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            model.getKickStreamInfo(stream: stream) { info in
                if let info {
                    kickTitle = info.title
                    kickCategory = info.categoryName ?? ""
                }
            }
        }
    }

    var body: some View {
        Form {
            if stream.twitchLoggedIn {
                Section {
                    TwitchStreamLiveSettingsView(model: model,
                                                 stream: model.stream,
                                                 title: $twitchTitle,
                                                 category: $twitchCategory)
                } header: {
                    TwitchLogoAndNameView(channel: stream.twitchChannelName)
                }
            }
            if stream.kickLoggedIn {
                Section {
                    KickStreamLiveSettingsView(model: model,
                                               stream: model.stream,
                                               title: $kickTitle,
                                               category: $kickCategory)
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
            loadTwitchStreamInfo()
            loadKickStreamInfo()
        }
    }
}
