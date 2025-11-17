import SwiftUI

struct ZoomSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var zoom: SettingsZoom

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Speed")
                    Slider(
                        value: $zoom.speed,
                        in: 1 ... 10,
                        step: 0.1
                    )
                    Text(String(formatOneDecimal(zoom.speed)))
                        .frame(width: 35)
                }
            }
            Section {
                List {
                    ForEach(zoom.back) { preset in
                        ZoomPresetSettingsView(
                            preset: preset,
                            minX: minZoomX,
                            maxX: model.getMinMaxZoomX(position: .back).1
                        )
                        .deleteDisabled(zoom.back.count == 1)
                    }
                    .onMove { froms, to in
                        zoom.back.move(fromOffsets: froms, toOffset: to)
                        model.backZoomPresetSettingsUpdated()
                    }
                    .onDelete { offsets in
                        zoom.back.remove(atOffsets: offsets)
                        model.backZoomPresetSettingsUpdated()
                    }
                }
                CreateButtonView {
                    zoom.back.append(SettingsZoomPreset(
                        id: UUID(),
                        name: "1x",
                        x: 1.0
                    ))
                    model.backZoomPresetSettingsUpdated()
                }
            } header: {
                Text("Back camera presets")
            } footer: {
                SwipeLeftToDeleteHelpView(kind: String(localized: "a preset"))
            }
            Section {
                List {
                    ForEach(zoom.front) { preset in
                        ZoomPresetSettingsView(
                            preset: preset,
                            minX: minZoomX,
                            maxX: model.getMinMaxZoomX(position: .front).1
                        )
                        .deleteDisabled(zoom.front.count == 1)
                    }
                    .onMove { froms, to in
                        zoom.front.move(fromOffsets: froms, toOffset: to)
                        model.frontZoomPresetSettingUpdated()
                    }
                    .onDelete { offsets in
                        zoom.front.remove(atOffsets: offsets)
                        model.frontZoomPresetSettingUpdated()
                    }
                }
                CreateButtonView {
                    zoom.front.append(SettingsZoomPreset(
                        id: UUID(),
                        name: "1x",
                        x: 1.0
                    ))
                    model.frontZoomPresetSettingUpdated()
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
                    defaultZoom: zoom.switchToBack
                )
                ZoomSwitchToSettingsView(
                    name: String(localized: "front"),
                    position: .front,
                    defaultZoom: zoom.switchToFront
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
