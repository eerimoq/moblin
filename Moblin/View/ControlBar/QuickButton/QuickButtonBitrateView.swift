import SwiftUI

struct QuickButtonBitrateView: View {
    @EnvironmentObject var model: Model
    @State var selection: UInt32
    var done: () -> Void

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
                    model.makeToast(title: formatBytesPerSecond(speed: Int64(bitrate)))
                    done()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Bitrate")
        .toolbar {
            SettingsToolbar(quickDone: done)
        }
    }
}
