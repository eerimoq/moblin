import SwiftUI

struct MusicSpotifySettingsView: View {
    let model: Model
    @ObservedObject var spotify: SettingsSpotify

    var body: some View {
        Form {
            Section {
                Text(String("""
                Report in Discord if this feature does not work. Spotify \
                may have quota limitations...
                """))
            }
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
