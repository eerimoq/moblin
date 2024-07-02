import SwiftUI

struct StreamOverlayRightZoomPresetSelctorView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.cameraPosition == .front {
                SegmentedPicker(model.frontZoomPresets(), selectedItem: Binding(get: {
                    model.frontZoomPresets().first { $0.id == model.frontZoomPresetId }
                }, set: { value in
                    if let value {
                        model.frontZoomPresetId = value.id
                    }
                })) {
                    Text($0.name)
                        .font(.subheadline)
                        .frame(width: zoomSegmentWidth, height: segmentHeight)
                }
                .onChange(of: model.frontZoomPresetId) { id in
                    model.setCameraZoomPreset(id: id)
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: zoomSegmentWidth * Double(model.frontZoomPresets().count))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
                .padding([.bottom], 5)
            } else {
                SegmentedPicker(model.backZoomPresets(), selectedItem: Binding(get: {
                    model.backZoomPresets().first { $0.id == model.backZoomPresetId }
                }, set: { value in
                    if let value {
                        model.backZoomPresetId = value.id
                    }
                })) {
                    Text($0.name)
                        .font(.subheadline)
                        .frame(width: zoomSegmentWidth, height: segmentHeight)
                }
                .onChange(of: model.backZoomPresetId) { id in
                    model.setCameraZoomPreset(id: id)
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: zoomSegmentWidth * Double(model.backZoomPresets().count))
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
