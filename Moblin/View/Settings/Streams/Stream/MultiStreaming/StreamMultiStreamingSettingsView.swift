import SwiftUI

private struct DestinationView: View {
    @EnvironmentObject var model: Model
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
                            .disabled(stream.enabled && (model.isLive || model.isRecording))
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
            .disabled(stream.enabled && (model.isLive || model.isRecording))
        }
    }
}

struct StreamMultiStreamingSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var multiStreaming: SettingsStreamMultiStreaming

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    Text("Stream to additional destinations directly from this device.")
                    Text("")
                    Text("""
                    ⚠️ Requires more bandwidth and increases the overall load on your \
                    device. Avoid when streaming IRL!
                    """)
                }
            }
            Section {
                List {
                    let items = ForEach(multiStreaming.destinations) {
                        DestinationView(stream: stream, destination: $0)
                    }
                    if stream.enabled && (model.isLive || model.isRecording) {
                        items
                    } else {
                        items
                            .onDelete {
                                multiStreaming.destinations.remove(atOffsets: $0)
                            }
                    }
                }
                CreateButtonView {
                    let destination = SettingsStreamMultiStreamingDestination()
                    multiStreaming.destinations.append(destination)
                }
                .disabled(stream.enabled && (model.isLive || model.isRecording))
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a destination"))
            }
        }
        .navigationTitle("Multi streaming")
    }
}
