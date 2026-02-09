import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PreferenceView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Preference")
                }

            PublishView()
                .tabItem {
                    Image(systemName: "record.circle")
                    Text("Publish")
                }

            if #available(iOS 17.0, *), UIDevice.current.userInterfaceIdiom == .pad {
                UVCView()
                    .tabItem {
                        Image(systemName: "record.circle")
                        Text("UVC Camera")
                    }
            }

            PlaybackView()
                .tabItem {
                    Image(systemName: "play.circle")
                    Text("Playback")
                }
        }
    }
}
