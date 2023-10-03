import SwiftUI

struct ZoomSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section("Back") {
                List {
                    ForEach(model.database.zoom!.back!) { level in
                        NavigationLink(destination: ZoomLevelSettingsView(
                            model: model,
                            level: level
                        )) {
                            TextItemView(name: level.name, value: String(level.level))
                        }
                        .deleteDisabled(model.database.zoom!.back!.count == 1)
                    }
                    .onMove(perform: { froms, to in
                        model.database.zoom!.back!.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated(store: true)
                        model.objectWillChange.send()
                    })
                    .onDelete(perform: { offsets in
                        model.database.zoom!.back!.remove(atOffsets: offsets)
                        model.sceneUpdated(store: true)
                        model.objectWillChange.send()
                    })
                }
                CreateButtonView(action: {
                    model.database.zoom!.back!.append(SettingsZoomLevel(
                        id: UUID(),
                        name: "1x",
                        level: 1.0
                    ))
                    model.sceneUpdated(store: true)
                    model.objectWillChange.send()
                })
            }
            Section("Front") {
                List {
                    ForEach(model.database.zoom!.front!) { level in
                        NavigationLink(destination: ZoomLevelSettingsView(
                            model: model,
                            level: level
                        )) {
                            TextItemView(name: level.name, value: String(level.level))
                        }
                        .deleteDisabled(model.database.zoom!.front!.count == 1)
                    }
                    .onMove(perform: { froms, to in
                        model.database.zoom!.front!.move(fromOffsets: froms, toOffset: to)
                        model.sceneUpdated(store: true)
                        model.objectWillChange.send()
                    })
                    .onDelete(perform: { offsets in
                        model.database.zoom!.front!.remove(atOffsets: offsets)
                        model.sceneUpdated(store: true)
                        model.objectWillChange.send()
                    })
                }
                CreateButtonView(action: {
                    model.database.zoom!.front!.append(SettingsZoomLevel(
                        id: UUID(),
                        name: "1x",
                        level: 1.0
                    ))
                    model.sceneUpdated(store: true)
                    model.objectWillChange.send()
                })
            }
        }
        .navigationTitle("Zoom")
    }
}
