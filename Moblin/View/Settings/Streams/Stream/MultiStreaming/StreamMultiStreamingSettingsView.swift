import SwiftUI

private struct DestinationView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var destination: SettingsStreamMultiStreamingDestination

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $destination.name, existingNames: stream.multiStreaming.destinations)
                }
                Section {
                    NavigationLink {
                        StreamMultiStreamingUrlView(stream: stream, destination: destination)
                            .disabled(stream.enabled && (model.isLive || model.isRecording))
                    } label: {
                        TextItemView(name: String(localized: "URL"), value: destination.url, sensitive: true)
                    }
                }
            }
            .navigationTitle("Destination")
        } label: {
            Toggle(isOn: $destination.enabled) {
                Text(destination.name)
            }
            .onChange(of: destination.enabled) { _ in
                model.reloadStreamIfEnabled(stream: stream)
            }
            .disabled(stream.enabled && (model.isLive || model.isRecording))
        }
    }
}

struct StreamMultiStreamingSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var multiStreaming: SettingsStreamMultiStreaming

    private func numberOfEnabledDestinations() -> String {
        let count = multiStreaming.destinations.filter { $0.enabled }.count
        return String(count)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        Text("Stream to additional destinations directly from this device.")
                        Text("")
                        Text("⚠️ This will increase network bandwidth usage, system load and device heat.")
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
                        destination.name = makeUniqueName(
                            name: SettingsStreamMultiStreamingDestination.baseName,
                            existingNames: multiStreaming.destinations
                        )
                        multiStreaming.destinations.append(destination)
                    }
                    .disabled(stream.enabled && (model.isLive || model.isRecording))
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a destination"))
                }
            }
            .navigationTitle("Multi streaming")
        } label: {
            HStack {
                Text("Multi streaming")
                Spacer()
                Text(numberOfEnabledDestinations())
                    .foregroundStyle(.gray)
            }
        }
    }
}
