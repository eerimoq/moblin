import SwiftUI

struct StreamVideoBitrateSettingsView: View {
    @EnvironmentObject var model: Model
    @Environment(\.dismiss) var dismiss
    var stream: SettingsStream
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
                    stream.bitrate = bitrate
                    model.store()
                    if stream.enabled {
                        model.setStreamBitrate(stream: stream)
                    }
                    dismiss()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Bitrate")
        .toolbar {
            SettingsToolbar()
        }
    }
}

struct StreamVideoBitrateSettingsButtonView: View {
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
                    model.stream.bitrate = bitrate
                    model.store()
                    if model.stream.enabled {
                        model.setStreamBitrate(stream: model.stream)
                    }
                    model
                        .makeToast(title: formatBytesPerSecond(speed: Int64(bitrate)))
                    done()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Bitrate")
        .toolbar {
            QuickSettingsToolbar(done: done)
        }
    }
}
