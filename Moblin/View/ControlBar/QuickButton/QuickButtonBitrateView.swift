import SwiftUI

struct QuickButtonBitrateView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Section {
                Picker("", selection: $stream.bitrate) {
                    ForEach(database.bitratePresets) { preset in
                        Text(formatBytesPerSecond(speed: Int64(preset.bitrate)))
                            .tag(preset.bitrate)
                    }
                }
                .onChange(of: stream.bitrate) { bitrate in
                    model.setBitrate(bitrate: bitrate)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                NavigationLink {
                    BitratePresetsSettingsView(database: model.database)
                } label: {
                    Label("Bitrate presets", systemImage: "speedometer")
                }
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle("Bitrate")
    }
}
