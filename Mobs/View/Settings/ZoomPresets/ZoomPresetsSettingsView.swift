import SwiftUI

struct ZoomPresetsSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section("Back camera") {
                List {
                    ForEach(model.database.zoom!.back) { preset in
                        NavigationLink(destination: ZoomPresetsPresetSettingsView(
                            model: model,
                            preset: preset,
                            position: .back
                        )) {
                            TextItemView(
                                name: preset.name,
                                value: String(factorToX(
                                    position: .back,
                                    factor: preset.level
                                ))
                            )
                        }
                        .deleteDisabled(model.database.zoom!.back.count == 1)
                    }
                    .onMove(perform: { froms, to in
                        model.database.zoom!.back.move(fromOffsets: froms, toOffset: to)
                        model.backZoomUpdated()
                    })
                    .onDelete(perform: { offsets in
                        model.database.zoom!.back.remove(atOffsets: offsets)
                        model.backZoomUpdated()
                    })
                }
                CreateButtonView(action: {
                    model.database.zoom!.back.append(SettingsZoomPreset(
                        id: UUID(),
                        name: "1x",
                        level: xToFactor(position: .back, x: 1.0)
                    ))
                    model.backZoomUpdated()
                })
            }
            Section("Front camera") {
                List {
                    ForEach(model.database.zoom!.front) { preset in
                        NavigationLink(destination: ZoomPresetsPresetSettingsView(
                            model: model,
                            preset: preset,
                            position: .front
                        )) {
                            TextItemView(name: preset.name, value: String(preset.level))
                        }
                        .deleteDisabled(model.database.zoom!.front.count == 1)
                    }
                    .onMove(perform: { froms, to in
                        model.database.zoom!.front.move(fromOffsets: froms, toOffset: to)
                        model.frontZoomUpdated()
                    })
                    .onDelete(perform: { offsets in
                        model.database.zoom!.front.remove(atOffsets: offsets)
                        model.frontZoomUpdated()
                    })
                }
                CreateButtonView(action: {
                    model.database.zoom!.front.append(SettingsZoomPreset(
                        id: UUID(),
                        name: "1x",
                        level: 1.0
                    ))
                    model.frontZoomUpdated()
                })
            }
        }
        .navigationTitle("Zoom presets")
    }
}
