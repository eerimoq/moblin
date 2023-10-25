import SwiftUI

struct BitratePresetsSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

    var body: some View {
        Form {
            List {
                ForEach(model.database.bitratePresets) { preset in
                    NavigationLink(destination: BitratePresetsPresetSettingsView(
                        model: model,
                        preset: preset,
                        toolbar: toolbar
                    )) {
                        HStack {
                            DraggableItemPrefixView()
                            TextItemView(
                                name: formatBytesPerSecond(speed: Int64(preset.bitrate)),
                                value: String(bitrateToMbps(bitrate: preset.bitrate))
                            )
                        }
                    }
                    .deleteDisabled(model.database.bitratePresets.count == 1)
                }
                .onMove(perform: { froms, to in
                    model.database.bitratePresets.move(fromOffsets: froms, toOffset: to)
                    model.store()
                })
                .onDelete(perform: { offsets in
                    model.database.bitratePresets.remove(atOffsets: offsets)
                    model.store()
                })
            }
            CreateButtonView(action: {
                model.database.bitratePresets.append(SettingsBitratePreset(
                    id: UUID(),
                    bitrate: 1_000_000
                ))
                model.store()
            })
        }
        .navigationTitle("Bitrate presets")
        .toolbar {
            toolbar
        }
    }
}
