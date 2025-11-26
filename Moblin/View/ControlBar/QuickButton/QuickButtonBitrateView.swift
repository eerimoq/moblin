import SwiftUI

private struct BitratePresetView: View {
    @ObservedObject var preset: SettingsBitratePreset

    var body: some View {
        Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
            .tag(preset.bitrate)
    }
}

struct QuickButtonBitrateView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            if stream !== fallbackStream {
                Section {
                    Picker("", selection: $stream.bitrate) {
                        ForEach(database.bitratePresets) { preset in
                            BitratePresetView(preset: preset)
                        }
                    }
                    .onChange(of: stream.bitrate) { bitrate in
                        model.setBitrate(bitrate: bitrate)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            Section {
                NavigationLink {
                    BitratePresetsSettingsView(database: model.database)
                } label: {
                    Label("Bitrate presets", systemImage: "dot.radiowaves.left.and.right")
                }
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle("Bitrate")
    }
}
