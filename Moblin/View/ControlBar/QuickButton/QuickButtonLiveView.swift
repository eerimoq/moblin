import SwiftUI

private struct TwitchView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @Binding var title: String?
    @Binding var category: String?

    var body: some View {
        Section {
            if stream.twitchLoggedIn {
                TwitchStreamLiveSettingsView(model: model, stream: stream, title: $title, category: $category)
            }
        } header: {
            TwitchLogoAndNameView(channel: stream.twitchChannelName)
        }
    }
}

private struct KickView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @Binding var title: String?
    @Binding var category: String?

    var body: some View {
        Section {
            if stream.kickLoggedIn {
                KickStreamLiveSettingsView(model: model, stream: stream, title: $title, category: $category)
            }
        } header: {
            KickLogoAndNameView(channel: stream.kickChannelName)
        }
    }
}

private struct YouTubeView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Section {} header: {
            YouTubeLogoAndNameView(handle: stream.youTubeHandle)
        }
    }
}

private struct DLiveView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Section {} header: {
            DLiveLogoAndNameView(username: stream.dLiveUsername)
        }
    }
}

private struct SoopView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Section {} header: {
            SoopLogoAndNameView(channel: stream.soopChannelName)
        }
    }
}

private struct GoLiveNotificationView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream

    var body: some View {
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
}

private struct ShortcutView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Section {
            NavigationLink {
                Form {
                    StreamPlatformsSettingsView(stream: stream)
                }
                .navigationTitle("Streaming platforms")
            } label: {
                Label("Streaming platforms", systemImage: "dot.radiowaves.left.and.right")
            }
            if database.showAllSettings {
                NavigationLink {
                    GoLiveNotificationSettingsView(stream: stream)
                } label: {
                    Label("Go live notification", systemImage: "dot.radiowaves.left.and.right")
                }
            }
        } header: {
            Text("Shortcut")
        }
    }
}

struct QuickButtonLiveView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream
    @State private var twitchTitle: String?
    @State private var twitchCategory: String?
    @State private var kickTitle: String?
    @State private var kickCategory: String?

    private func anyStreamingPlatformConfigured() -> Bool {
        if !stream.twitchChannelName.isEmpty {
            return true
        }
        if !stream.kickChannelName.isEmpty {
            return true
        }
        if !stream.youTubeHandle.isEmpty {
            return true
        }
        if !stream.dLiveUsername.isEmpty {
            return true
        }
        if !stream.soopChannelName.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        Form {
            if stream !== fallbackStream {
                if !anyStreamingPlatformConfigured() {
                    Text("No 'Streaming platform' is configured.")
                }
                if !stream.twitchChannelName.isEmpty {
                    TwitchView(model: model, stream: stream, title: $twitchTitle, category: $twitchCategory)
                }
                if !stream.kickChannelName.isEmpty {
                    KickView(model: model, stream: stream, title: $kickTitle, category: $kickCategory)
                }
                if !stream.youTubeHandle.isEmpty {
                    YouTubeView(stream: stream)
                }
                if !stream.dLiveUsername.isEmpty {
                    DLiveView(stream: stream)
                }
                if !stream.soopChannelName.isEmpty {
                    SoopView(stream: stream)
                }
                if database.showAllSettings {
                    if stream.goLiveNotificationDiscordWebhookUrl.isEmpty {
                        Section {
                            Text("No 'Go live notification' is configured.")
                        }
                    } else {
                        GoLiveNotificationView(model: model, database: database, stream: stream)
                    }
                }
                ShortcutView(model: model, database: database, stream: stream)
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
