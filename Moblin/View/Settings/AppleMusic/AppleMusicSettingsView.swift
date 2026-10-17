import MusicKit
import SwiftUI

struct MusicArtistView: View {
    let artist: String

    var body: some View {
        Text(artist)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

func formatMusicDuration(_ duration: Int) -> String {
    let seconds = String(format: "%02d", duration % 60)
    if duration < 3600 {
        return "\(duration / 60):\(seconds)"
    }
    let minutes = String(format: "%02d", duration / 60 % 60)
    return "\(duration / 3600):\(minutes):\(seconds)"
}

struct MusicDurationView: View {
    let duration: Int

    var body: some View {
        Text(formatMusicDuration(duration))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}

private struct PlaylistEndView: View {
    @ObservedObject var musicPlaylist: MusicPlaylist
    @ObservedObject var queue: ApplicationMusicPlayer.Queue

    var body: some View {
        let currentIndex = musicPlaylist.currentIndex()
        let remaining = musicPlaylist.songs()[(currentIndex ?? 0)...].compactMap(\.duration)
        if !remaining.isEmpty {
            TimelineView(.periodic(from: .now, by: 10)) { context in
                let playbackTime = currentIndex == nil ? 0 : musicPlayer.playbackTime
                let end = context.date + Double(remaining.reduce(0, +)) - playbackTime
                Text("Ends \(end, style: .time)")
                    .monospacedDigit()
            }
        }
    }
}

struct MusicAddedByView: View {
    let user: String

    var body: some View {
        Text("added by \(Text(user).foregroundColor(.primary).fontWeight(.medium))")
            .font(.subheadline)
            .foregroundStyle(.gray)
    }
}

private struct ControlsView: View {
    let model: Model
    @ObservedObject var playerState: ApplicationMusicPlayer.State
    let isEmpty: Bool

    var body: some View {
        Section {
            HStack {
                Spacer()
                Button {
                    model.previousMusic(count: 1)
                } label: {
                    Image(systemName: "arrow.backward.to.line")
                }
                .buttonStyle(.borderless)
                Spacer()
                let isPlaying = playerState.playbackStatus == .playing
                Button {
                    if isPlaying {
                        model.pauseMusic()
                    } else {
                        model.playMusic()
                    }
                } label: {
                    ZStack {
                        Image(systemName: "play")
                            .opacity(isPlaying ? 0 : 1)
                        Image(systemName: "pause")
                            .opacity(isPlaying ? 1 : 0)
                    }
                }
                .buttonStyle(.borderless)
                Spacer()
                Button {
                    model.nextMusic(count: 1)
                } label: {
                    Image(systemName: "arrow.forward.to.line")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .disabled(isEmpty)
            .font(.title)
        }
    }
}

private struct PlaylistView: View {
    let model: Model
    @ObservedObject var musicPlaylist: MusicPlaylist
    @ObservedObject var queue: ApplicationMusicPlayer.Queue

    var body: some View {
        let songs = musicPlaylist.songs()
        let currentIndex = musicPlaylist.currentIndex()
        Section {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                HStack {
                    let isPlaying = index == currentIndex
                    if isPlaying {
                        Image(systemName: "music.quarternote.3")
                    }
                    VStack(alignment: .leading) {
                        if isPlaying {
                            Text(song.title)
                                .bold()
                        } else {
                            Text(song.title)
                        }
                        if let artist = song.artist {
                            MusicArtistView(artist: artist)
                        }
                        if let user = song.addedBy {
                            MusicAddedByView(user: user)
                        }
                    }
                    Spacer()
                    if let duration = song.duration {
                        MusicDurationView(duration: duration)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectMusic(entryId: song.id)
                }
            }
            .onDelete { offsets in
                for offset in offsets {
                    model.removeMusic(entryId: songs[offset].id)
                }
            }
        } header: {
            HStack {
                Text("Playlist")
                Spacer()
                PlaylistEndView(musicPlaylist: musicPlaylist, queue: queue)
            }
        }
    }
}

private struct SongRequestsView: View {
    let model: Model
    @ObservedObject var moblinCloud: SettingsMoblinCloud

    var body: some View {
        if moblinCloud.enabled {
            Section {
                Toggle("Song requests", isOn: $moblinCloud.songRequests)
                    .onChange(of: moblinCloud.songRequests) { _ in
                        model.moblinCloudSendSongRequests()
                    }
            } header: {
                Text("Moblin Cloud")
            }
        }
    }
}

struct AppleMusicSettingsView: View {
    let model: Model
    @ObservedObject var musicPlaylist: MusicPlaylist
    @State private var searchText: String = ""
    @State private var isShowingSubscriptionOffer: Bool = false
    @State private var musicSubscription: MusicSubscription?

    var body: some View {
        Form {
            if musicSubscription?.canBecomeSubscriber == true {
                Section {
                    Button {
                        isShowingSubscriptionOffer = true
                    } label: {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Join")
                        }
                    }
                }
            }
            ControlsView(
                model: model,
                playerState: musicPlayer.state,
                isEmpty: musicPlaylist.state != .loaded
            )
            Section {
                TextField("Add song", text: $searchText)
                    .onSubmit {
                        model.addMusic(title: searchText, user: nil) { _ in }
                    }
            }
            SongRequestsView(model: model, moblinCloud: model.database.moblinCloud)
            PlaylistView(model: model, musicPlaylist: musicPlaylist, queue: musicPlaylist.queue)
        }
        .onAppear {
            model.loadMusic()
        }
        .task {
            for await subscription in MusicSubscription.subscriptionUpdates {
                musicSubscription = subscription
            }
        }
        .musicSubscriptionOffer(isPresented: $isShowingSubscriptionOffer,
                                options: MusicSubscriptionOffer.Options.default)
        .navigationTitle("Apple Music")
    }
}
