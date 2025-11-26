import SwiftUI

struct StreamAudioSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @State var bitrate: Float

    private func calcBitrate() -> Int {
        return Int((bitrate * 1000).rounded(.up))
    }

    var body: some View {
        Form {
            Section {
                Picker("Codec", selection: $stream.audioCodec) {
                    ForEach(SettingsStreamAudioCodec.allCases, id: \.self) {
                        Text($0.toString())
                    }
                }
                .onChange(of: stream.audioCodec) { _ in
                    model.reloadStreamIfEnabled(stream: stream)
                }
                .disabled(stream.enabled && model.isLive)
            }
            Section {
                HStack {
                    Slider(
                        value: $bitrate,
                        in: 32 ... 320,
                        step: 32,
                        label: {
                            EmptyView()
                        },
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            stream.audioBitrate = calcBitrate()
                            if stream.enabled {
                                model.setAudioStreamBitrate(stream: stream)
                            }
                        }
                    )
                    Text(formatBytesPerSecond(speed: Int64(calcBitrate())))
                        .frame(width: 90)
                }
                .disabled(stream.enabled && model.isLive)
            } header: {
                Text("Bitrate")
            } footer: {
                VStack(alignment: .leading) {
                    Text("128 Kbps or higher is recommended.")
                    Text("")
                    Text("The actual bitrate may be lower if the device does not support it.")
                }
            }
        }
        .navigationTitle("Audio")
    }
}
