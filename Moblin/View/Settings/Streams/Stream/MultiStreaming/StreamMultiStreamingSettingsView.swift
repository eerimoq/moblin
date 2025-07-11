import SwiftUI

struct StreamMultiStreamingSettingsView: View {
    @ObservedObject var multiStreaming: SettingsStreamMultiStreaming

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(multiStreaming.destinations) { destination in
                        NavigationLink {
                            Text(destination.url)
                        } label: {
                            TextItemView(name: String(localized: "URL"), value: schemeAndAddress(url: destination.url))
                        }
                    }
                    .onDelete {
                        multiStreaming.destinations.remove(atOffsets: $0)
                    }
                }
                CreateButtonView {
                    let destination = SettingsStreamMultiStreamingDestination()
                    destination.url = "rtmp://192.168.50.181:1935/live/1"
                    multiStreaming.destinations.append(destination)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a destination"))
            }
        }
        .navigationTitle("Multi streaming")
    }
}
