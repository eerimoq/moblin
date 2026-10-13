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

struct MusicAddedByView: View {
    let user: String

    var body: some View {
        Text("Added by: \(user)")
            .font(.subheadline)
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
                if playerState.playbackStatus == .playing {
                    Button {
                        model.pauseMusic()
                    } label: {
                        Image(systemName: "pause")
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        model.playMusic()
                    } label: {
                        Image(systemName: "play")
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
            }
            .disabled(isEmpty)
            .font(.title)
        }
    }
}

private struct PlaylistView: View {
    let model: Model
    let songs: [MusicPlaylistSong]
    @ObservedObject var queue: ApplicationMusicPlayer.Queue

    var body: some View {
        let currentIndex = musicCurrentIndex(queue: queue)
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
            Text("Playlist")
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
            ControlsView(model: model, playerState: musicPlayer.state, isEmpty: musicPlaylist.songs.isEmpty)
            Section {
                TextField("Add song", text: $searchText)
                    .onSubmit {
                        model.addMusic(title: searchText, user: nil) { _ in }
                    }
            }
            PlaylistView(model: model, songs: musicPlaylist.songs, queue: musicPlaylist.queue)
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
