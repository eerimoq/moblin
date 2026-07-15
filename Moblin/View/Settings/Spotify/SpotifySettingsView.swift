import SwiftUI

struct SpotifySettingsView: View {
    let model: Model
    @ObservedObject var spotify: SettingsSpotify

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $spotify.enabled)
                    .onChange(of: spotify.enabled) { _ in
                        model.reloadSpotify()
                    }
            }
        }
        .navigationTitle("Spotify")
    }
}
