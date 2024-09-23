import SwiftUI

struct QuickButtonBitrateView: View {
    @EnvironmentObject var model: Model
    @State var selection: UInt32

    var body: some View {
        Form {
            Section {
                Picker("", selection: $selection) {
                    ForEach(model.database.bitratePresets) { preset in
                        Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                            .tag(preset.bitrate)
                    }
                }
                .onChange(of: selection) { bitrate in
                    model.setBitrate(bitrate: bitrate)
                    if model.stream.enabled {
                        model.setStreamBitrate(stream: model.stream)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Bitrate")
    }
}
