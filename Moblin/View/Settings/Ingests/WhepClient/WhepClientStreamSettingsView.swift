import SwiftUI

struct WhepClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var whepClient: SettingsWhepClient
    @ObservedObject var stream: SettingsWhepClientStream

    private var audioOffsetMinMs: Double {
        max(-2000, -Double(stream.latency))
    }

    private var audioOffsetBinding: Binding<Double> {
        Binding(
            get: { Double(stream.audioOffset) },
            set: { stream.audioOffset = Int32($0.rounded()) }
        )
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: whepClient.streams)
                        .disabled(stream.enabled)
                }
                Section {
                    NavigationLink {
                        UrlSettingsView(disabled: stream.enabled,
                                        url: $stream.url,
                                        value: stream.url,
                                        placeholder: "http://foo.com/whep",
                                        allowedSchemes: ["http", "https"],
                                        examples: [],
                                        onSubmitted: model.reloadWhepClient)
                    } label: {
                        TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                    }
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(stream.latency),
                        onChange: isValidIngestLatency,
                        onSubmit: {
                            guard let latency = Int32($0) else {
                                return
                            }
                            stream.latency = latency
                            stream.audioOffset = max(stream.audioOffset, -stream.latency)
                            model.reloadWhepClient()
                        },
                        footers: [String(localized: "5 or more milliseconds. 100 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                    .disabled(stream.enabled)
                } footer: {
                    Text("The higher, the lower risk of stuttering.")
                }
                Section {
                    Toggle("Sync timestamps", isOn: $stream.syncTimestamps)
                        .onChange(of: stream.syncTimestamps) { _ in
                            model.reloadWhepClient()
                        }
                        .disabled(stream.enabled)
                }
                Section {
                    VStack(alignment: .leading) {
                        Text("Audio offset")
                        HStack {
                            Slider(value: audioOffsetBinding, in: audioOffsetMinMs ... 2000, step: 10)
                                .onChange(of: stream.audioOffset) { _ in
                                    model.setWhepStreamAudioOffset(stream: stream)
                                }
                            Text("\(stream.audioOffset) ms")
                                .frame(width: 65)
                        }
                    }
                } footer: {
                    Text("Adjust to fix audio/video sync. Positive delays audio, negative advances it.")
                }
            }
            .navigationTitle("Stream")
        } label: {
            Toggle(isOn: $stream.enabled) {
                HStack {
                    Text(stream.name)
                }
            }
            .onChange(of: stream.enabled) { _ in
                model.reloadWhepClient()
            }
        }
    }
}
