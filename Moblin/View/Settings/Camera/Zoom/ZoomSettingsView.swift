import SwiftUI

struct ZoomSettingsView: View {
    @EnvironmentObject var model: Model
    @State var speed: Float

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Speed")
                    Slider(
                        value: $speed,
                        in: 1 ... 10,
                        step: 0.1,
                        onEditingChanged: { begin in
                            guard !begin else {
                                return
                            }
                            model.database.zoom.speed = speed
                        }
                    )
                    Text(String(formatOneDecimal(speed)))
                        .frame(width: 35)
                }
            }
            Section {
                List {
                    ForEach(model.database.zoom.back) { preset in
                        NavigationLink {
                            ZoomPresetSettingsView(
                                preset: preset,
                                minX: minZoomX,
                                maxX: model.getMinMaxZoomX(position: .back).1
                            )
                        } label: {
                            HStack {
                                DraggableItemPrefixView()
                                TextItemView(
                                    name: preset.name,
                                    value: String(preset.x!)
                                )
                            }
                        }
                        .deleteDisabled(model.database.zoom.back.count == 1)
                    }
                    .onMove(perform: { froms, to in
                        model.database.zoom.back.move(fromOffsets: froms, toOffset: to)
                        model.backZoomUpdated()
                        model.objectWillChange.send()
                    })
                    .onDelete(perform: { offsets in
                        model.database.zoom.back.remove(atOffsets: offsets)
                        model.backZoomUpdated()
                        model.objectWillChange.send()
                    })
                }
                CreateButtonView {
                    model.database.zoom.back.append(SettingsZoomPreset(
                        id: UUID(),
                        name: "1x",
                        level: 1.0,
                        x: 1.0
                    ))
                    model.backZoomUpdated()
                    model.objectWillChange.send()
                }
            } header: {
                Text("Back camera presets")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a preset"))
            }
            Section {
                List {
                    ForEach(model.database.zoom.front) { preset in
                        NavigationLink {
                            ZoomPresetSettingsView(
                                preset: preset,
                                minX: minZoomX,
                                maxX: model.getMinMaxZoomX(position: .front).1
                            )
                        } label: {
                            HStack {
                                DraggableItemPrefixView()
                                TextItemView(
                                    name: preset.name,
                                    value: String(preset.x!)
                                )
                            }
                        }
                        .deleteDisabled(model.database.zoom.front.count == 1)
                    }
                    .onMove(perform: { froms, to in
                        model.database.zoom.front.move(fromOffsets: froms, toOffset: to)
                        model.frontZoomUpdated()
                        model.objectWillChange.send()
                    })
                    .onDelete(perform: { offsets in
                        model.database.zoom.front.remove(atOffsets: offsets)
                        model.frontZoomUpdated()
                        model.objectWillChange.send()
                    })
                }
                CreateButtonView {
                    model.database.zoom.front.append(SettingsZoomPreset(
                        id: UUID(),
                        name: "1x",
                        level: 1.0,
                        x: 1.0
                    ))
                    model.frontZoomUpdated()
                    model.objectWillChange.send()
                }
            } header: {
                Text("Front camera presets")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a preset"))
            }
            Section {
                ZoomSwitchToSettingsView(
                    name: String(localized: "back"),
                    position: .back,
                    defaultZoom: model.database.zoom.switchToBack
                )
                ZoomSwitchToSettingsView(
                    name: String(localized: "front"),
                    position: .front,
                    defaultZoom: model.database.zoom.switchToFront
                )
            } header: {
                Text("Camera switching")
            } footer: {
                Text("The zoom (in X) to set when switching to given camera, if enabled.")
            }
        }
        .navigationTitle("Zoom")
    }
}
