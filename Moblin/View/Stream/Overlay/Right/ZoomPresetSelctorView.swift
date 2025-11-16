import SwiftUI

private struct PickerItemView: View {
    @ObservedObject var preset: SettingsZoomPreset

    var body: some View {
        Text(preset.name)
            .font(.subheadline)
    }
}

private struct ZoomPresetView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @Binding var presets: [SettingsZoomPreset]
    @Binding var selectedPresetId: UUID
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
        SegmentedPicker(presets, selectedItem: Binding(get: {
            presets.first { $0.id == selectedPresetId }
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
        .foregroundStyle(.white)
        .frame(width: min(segmentWidth() * Double(presets.count), max(width - 20, 1)))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
        .padding([.bottom], 5)
    }
}

struct StreamOverlayRightZoomPresetSelctorView: View {
    let model: Model
    @ObservedObject var zoom: Zoom
    let width: CGFloat

    private func presets() -> Binding<[SettingsZoomPreset]> {
        if model.cameraPosition == .front {
            return $zoom.frontZoomPresets
        } else {
            return $zoom.backZoomPresets
        }
    }

    private func selectedPresetId() -> Binding<UUID> {
        if model.cameraPosition == .front {
            return $zoom.frontPresetId
        } else {
            return $zoom.backPresetId
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            ZoomPresetView(database: model.database,
                           presets: presets(),
                           selectedPresetId: selectedPresetId(),
                           width: width)
        }
    }
}
