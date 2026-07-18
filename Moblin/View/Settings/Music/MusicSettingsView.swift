import SwiftUI

struct MusicSettingsView: View {
    let model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    MusicAppleMusicSettingsView(model: model)
                } label: {
                    Text("Apple Music")
                }
                NavigationLink {
                    MusicSpotifySettingsView(model: model, spotify: model.database.spotify)
                } label: {
                    Text("Spotify")
                }
            }
        }
        .navigationTitle("Music")
    }
}
