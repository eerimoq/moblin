import MusicKit
import SwiftUI

struct MusicAppleMusicSettingsView: View {
    let model: Model
    @State private var searchText: String = ""
    @ObservedObject private var playerState = musicPlayer.state
    @ObservedObject private var playerQueue = musicPlayer.queue
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
                    Button {
                        model.nextMusic(count: 1)
                    } label: {
                        Image(systemName: "arrow.forward.to.line")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                }
                .disabled(playerQueue.entries.isEmpty)
                .font(.title)
            }
            Section {
                TextField("Add song", text: $searchText)
                    .onSubmit {
                        model.addMusic(title: searchText) { _ in }
                    }
            }
            Section {
                ForEach(playerQueue.entries) { entry in
                    if entry.id == playerQueue.currentEntry?.id {
                        Text("• \(entry.title)")
                            .bold()
                    } else {
                        Text(entry.title)
                    }
                }
            } header: {
                Text("Playlist")
            }
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
