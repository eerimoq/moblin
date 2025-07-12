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
                        Text("⚠️ This will increase bandwidth usage, system load and device heat.")
                        Text("")
                        Text("""
                        ⚠️ Not recommended to use on the road, but only in the comfort of your \
                        home where internet is good and it's close to a fire extinguisher. 🤣
                        """)
                        Text("")
                        Text("YOU HAVE BEEN WARNED!!!")
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
                        multiStreaming.destinations.append(SettingsStreamMultiStreamingDestination())
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
                    .foregroundColor(.gray)
            }
        }
    }
}
