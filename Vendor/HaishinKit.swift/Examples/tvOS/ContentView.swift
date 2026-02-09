import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PlaybackView()
                .tabItem {
                    Image(systemName: "play.circle")
                    Text("Playback")
                }

            PreferenceView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Preference")
                }
        }
    }
}

#Preview {
    ContentView()
}
