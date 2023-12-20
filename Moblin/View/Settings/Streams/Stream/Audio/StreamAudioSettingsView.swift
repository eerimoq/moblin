import SwiftUI

struct StreamAudioSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var bitrate: Float

    private func calcBitrate() -> Int {
        return Int((bitrate * 1000).rounded(.up))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Slider(
                        value: $bitrate,
                        in: 32 ... 320,
                        step: 32,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            stream.audioBitrate = calcBitrate()
                            model.store()
                            if model.stream.enabled {
                                model.setAudioStreamBitrate(stream: stream)
                            }
                        }
                    )
                    Text(formatBytesPerSecond(speed: Int64(calcBitrate())))
                        .frame(width: 90)
                }
            } header: {
                Text("Bitrate")
            } footer: {
                VStack(alignment: .leading) {
                    Text("128 Kpbs or higher is recommended.")
                    Text("")
                    Text("The actual bitrate may be lower if the device does not support it.")
                }
            }
        }
        .navigationTitle("Audio")
        .toolbar {
            SettingsToolbar()
        }
    }
}
