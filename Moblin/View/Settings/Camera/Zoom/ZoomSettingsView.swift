import SwiftUI

struct ZoomSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var zoom: SettingsZoom

    private func deleteBackZoomPreset(at offsets: IndexSet) {
        zoom.back.remove(atOffsets: offsets)
        model.backZoomPresetSettingsUpdated()
    }

    private func deleteFrontZoomPreset(at offsets: IndexSet) {
        zoom.front.remove(atOffsets: offsets)
        model.frontZoomPresetSettingUpdated()
    }

    private func onColorChange(color: Color) {
        guard let color = color.toRgb() else {
            return
        }
        zoom.backgroundColor = color
        model.zoom.objectWillChange.send()
    }

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
                        .contextMenuDeleteButton(disabled: zoom.back.count == 1) {
                            if let offsets = makeOffsets(zoom.back, preset.id) {
                                deleteBackZoomPreset(at: offsets)
                            }
                        }
                    }
                    .onMove { froms, to in
                        zoom.back.move(fromOffsets: froms, toOffset: to)
                        model.backZoomPresetSettingsUpdated()
                    }
                    .onDelete(perform: deleteBackZoomPreset)
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
                        .contextMenuDeleteButton(disabled: zoom.front.count == 1) {
                            if let offsets = makeOffsets(zoom.front, preset.id) {
                                deleteFrontZoomPreset(at: offsets)
                            }
                        }
                    }
                    .onMove { froms, to in
                        zoom.front.move(fromOffsets: froms, toOffset: to)
                        model.frontZoomPresetSettingUpdated()
                    }
                    .onDelete(perform: deleteFrontZoomPreset)
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
            Section {
                ColorPicker("Background", selection: $zoom.backgroundColorColor)
                    .onChange(of: zoom.backgroundColorColor) { _ in
                        onColorChange(color: zoom.backgroundColorColor)
                    }
                TextButtonView("Reset") {
                    zoom.backgroundColorColor = defaultSegmentedPickerSelectedColor.color()
                    onColorChange(color: zoom.backgroundColorColor)
                }
            } header: {
                Text("Color")
            } footer: {
                Text("Background color of the zoom preset button when selected.")
            }
        }
        .navigationTitle("Zoom")
    }
}
