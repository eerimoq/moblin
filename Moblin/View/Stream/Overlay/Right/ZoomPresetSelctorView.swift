import SwiftUI

private struct PickerItemView: View {
    @ObservedObject var preset: SettingsZoomPreset

    var body: some View {
        Text(preset.name)
            .font(.subheadline)
    }
}

struct StreamOverlayRightZoomPresetSelctorView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var zoom: Zoom
    @ObservedObject var zoomSettings: SettingsZoom
    let width: CGFloat

    private func segmentWidth() -> Double {
        if database.bigButtons {
            return zoomSegmentWidthBig
        } else {
            return zoomSegmentWidth
        }
    }

    private func height() -> Double {
        if database.bigButtons {
            return segmentHeightBig
        } else {
            return segmentHeight
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.cameraPosition == .front {
                let presets = model.frontZoomPresets()
                SegmentedPicker(presets, selectedItem: Binding(get: {
                    presets.first { $0.id == zoom.frontPresetId }
                }, set: { value in
                    if let value {
                        model.setZoomPreset(id: value.id)
                    }
                })) {
                    PickerItemView(preset: $0)
                        .frame(
                            width: min(segmentWidth(), (width - 20) / CGFloat(presets.count)),
                            height: height()
                        )
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: min(segmentWidth() * Double(presets.count), width - 20))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
                .padding([.bottom], 5)
            } else {
                let presets = model.backZoomPresets()
                SegmentedPicker(presets, selectedItem: Binding(get: {
                    presets.first { $0.id == zoom.backPresetId }
                }, set: { value in
                    if let value {
                        model.setZoomPreset(id: value.id)
                    }
                })) {
                    PickerItemView(preset: $0)
                        .frame(
                            width: min(segmentWidth(), max((width - 20) / CGFloat(presets.count), 1)),
                            height: height()
                        )
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: min(segmentWidth() * Double(presets.count), max(width - 20, 1)))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
                .padding([.bottom], 5)
            }
        }
    }
}
