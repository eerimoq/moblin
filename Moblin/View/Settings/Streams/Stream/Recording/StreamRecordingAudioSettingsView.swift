import SwiftUI

struct StreamRecordingAudioSettingsView: View {
    @EnvironmentObject var model: Model
    var stream: SettingsStream
    @State var bitrate: Float

    private func calcBitrate() -> UInt32 {
        return UInt32((bitrate * 1000).rounded(.up))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Slider(
                        value: $bitrate,
                        in: 0 ... 192,
                        step: 32,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            stream.recording!.audioBitrate = calcBitrate()
                        }
                    )
                    Text(formatBytesPerSecond(speed: Int64(calcBitrate())))
                        .frame(width: 90)
                }
                .disabled(stream.enabled && model.isRecording)
            } header: {
                Text("Bitrate")
            } footer: {
                VStack(alignment: .leading) {
                    Text("128 Kpbs or higher is recommended. Set to 0 for automatic.")
                }
            }
        }
        .navigationTitle("Audio")
    }
}
