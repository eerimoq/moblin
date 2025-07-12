import SwiftUI

private struct DestinationView: View {
    @ObservedObject var stream: SettingsStream
    @ObservedObject var destination: SettingsStreamMultiStreamingDestination

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NavigationLink {
                        NameEditView(name: $destination.name)
                    } label: {
                        TextItemView(name: String(localized: "Name"), value: destination.name)
                    }
                }
                Section {
                    NavigationLink {
                        StreamMultiStreamingUrlView(stream: stream, destination: destination, value: destination.url)
                    } label: {
                        TextItemView(name: String(localized: "URL"), value: schemeAndAddress(url: destination.url))
                    }
                }
            }
            .navigationTitle("Destination")
        } label: {
            Toggle(isOn: $destination.enabled) {
                HStack {
                    Text("Destination")
                    Spacer()
                    Text(destination.name)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

struct StreamMultiStreamingSettingsView: View {
    @ObservedObject var stream: SettingsStream
    @ObservedObject var multiStreaming: SettingsStreamMultiStreaming

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("Stream to additional destinations directly from this device.")
                    Text("")
                    Text("⚠️ Requires more bandwidth and increases the overall load on your device.")
                }
            }
            Section {
                List {
                    ForEach(multiStreaming.destinations) {
                        DestinationView(stream: stream, destination: $0)
                    }
                    .onDelete {
                        multiStreaming.destinations.remove(atOffsets: $0)
                    }
                }
                CreateButtonView {
                    let destination = SettingsStreamMultiStreamingDestination()
                    multiStreaming.destinations.append(destination)
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a destination"))
            }
        }
        .navigationTitle("Multi streaming")
    }
}
