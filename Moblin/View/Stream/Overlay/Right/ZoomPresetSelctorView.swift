import SwiftUI

struct StreamOverlayRightZoomPresetSelctorView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var zoom: Zoom
    let width: CGFloat

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.cameraPosition == .front {
                let presets = model.frontZoomPresets()
                SegmentedPicker(presets, selectedItem: Binding(get: {
                    presets.first { $0.id == zoom.frontZoomPresetId }
                }, set: { value in
                    if let value {
                        model.setZoomPreset(id: value.id)
                    }
                })) {
                    Text($0.name)
                        .font(.subheadline)
                        .frame(
                            width: min(zoomSegmentWidth, (width - 20) / CGFloat(presets.count)),
                            height: segmentHeight
                        )
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: min(zoomSegmentWidth * Double(presets.count), width - 20))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
                .padding([.bottom], 5)
            } else {
                let presets = model.backZoomPresets()
                SegmentedPicker(presets, selectedItem: Binding(get: {
                    presets.first { $0.id == zoom.backZoomPresetId }
                }, set: { value in
                    if let value {
                        model.setZoomPreset(id: value.id)
                    }
                })) {
                    Text($0.name)
                        .font(.subheadline)
                        .frame(
                            width: min(zoomSegmentWidth, (width - 20) / CGFloat(presets.count)),
                            height: segmentHeight
                        )
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: min(zoomSegmentWidth * Double(presets.count), width - 20))
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
