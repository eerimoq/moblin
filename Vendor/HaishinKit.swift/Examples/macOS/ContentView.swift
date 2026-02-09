import SwiftUI

struct ContentView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case playback
        case publish
        case preference

        var id: String { rawValue }
    }

    @State private var selection: Tab = .playback

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label(tabTitle(tab), systemImage: tabIcon(tab)).onTapGesture {
                    selection = tab
                }
            }
        } detail: {
            switch selection {
            case .playback:
                PlaybackView()
            case .publish:
                PublishView()
            case .preference:
                PreferenceView()
            }
        }
    }

    private func tabTitle(_ tab: Tab) -> String {
        switch tab {
        case .playback:
            return "Playback"
        case .publish:
            return "Publish"
        case .preference:
            return "Preference"
        }
    }

    private func tabIcon(_ tab: Tab) -> String {
        switch tab {
        case .playback:
            return "play.circle"
        case .publish:
            return "record.circle"
        case .preference:
            return "info.circle"
        }
    }
}
