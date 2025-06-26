import SwiftUI

struct BitratePresetsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.bitratePresets) { preset in
                        BitratePresetsPresetSettingsView(preset: preset)
                            .deleteDisabled(database.bitratePresets.count == 1)
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
