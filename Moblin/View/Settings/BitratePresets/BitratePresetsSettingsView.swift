import SwiftUI

struct BitratePresetsSettingsView: View {
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.bitratePresets) { preset in
                        BitratePresetsPresetSettingsView(preset: preset)
                            .deleteDisabled(database.bitratePresets.count == 1)
                            .contextMenuDeleteButton(enabled: database.bitratePresets.count > 1) {
                                database.bitratePresets.removeAll { $0.id == preset.id }
                            }
                    }
                    .onMove { froms, to in
                        database.bitratePresets.move(fromOffsets: froms, toOffset: to)
                    }
                    .onDelete { offsets in
                        database.bitratePresets.remove(atOffsets: offsets)
                    }
                }
                CreateButtonView {
                    database.bitratePresets.append(SettingsBitratePreset(
                        id: UUID(),
                        bitrate: 1_000_000
                    ))
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a preset"))
            }
        }
        .navigationTitle("Bitrate presets")
    }
}
