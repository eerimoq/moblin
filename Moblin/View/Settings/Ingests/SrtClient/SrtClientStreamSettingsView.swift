import SwiftUI

struct SrtClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var srtClient: SettingsSrtClient
    @ObservedObject var stream: SettingsSrtClientStream

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
                    NameEditView(name: $stream.name, existingNames: srtClient.streams)
                }
                Section {
                    NavigationLink {
                        UrlSettingsView(
                            model: model,
                            disabled: false,
                            url: $stream.url,
                            value: stream.url,
                            placeholder: "srt://192.168.1.100:4000",
                            allowedSchemes: ["srt"],
                            examples: [
                                (
                                    "BELABOX cloud",
                                    "srt://eu.srt.belabox.net:4001?streamid=P3Kd229fslEWF3SGRQAsd"
                                ),
                            ],
                            onSubmitted: model.reloadSrtClient
                        )
                    } label: {
                        TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        Text("Audio offset")
                        HStack {
                            Slider(value: audioOffsetBinding, in: -2000 ... 2000, step: 10)
                                .onChange(of: stream.audioOffset) { _ in
                                    model.setSrtClientStreamAudioOffset(stream: stream)
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
                Text(stream.name)
            }
            .onChange(of: stream.enabled) { _ in
                model.reloadSrtClient()
            }
        }
    }
}
