import SwiftUI

struct BitratePresetsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.bitratePresets) { preset in
                        NavigationLink {
                            BitratePresetsPresetSettingsView(preset: preset)
                        } label: {
                            HStack {
                                DraggableItemPrefixView()
                                TextItemView(
                                    name: formatBytesPerSecond(speed: Int64(preset.bitrate)),
                                    value: String(bitrateToMbps(bitrate: preset.bitrate))
                                )
                            }
                        }
                        .deleteDisabled(database.bitratePresets.count == 1)
                    }
                    .onMove(perform: { froms, to in
                        database.bitratePresets.move(fromOffsets: froms, toOffset: to)
                    })
                    .onDelete(perform: { offsets in
                        database.bitratePresets.remove(atOffsets: offsets)
                    })
                }
                CreateButtonView {
                    database.bitratePresets.append(SettingsBitratePreset(
                        id: UUID(),
                        bitrate: 1_000_000
                    ))
                    model.objectWillChange.send()
                }
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a preset"))
            }
        }
        .navigationTitle("Bitrate presets")
    }
}
