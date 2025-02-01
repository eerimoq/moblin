import SwiftUI

struct StreamOverlayRightSceneSelectorView: View {
    @EnvironmentObject var model: Model
    let width: CGFloat

    var body: some View {
        SegmentedPicker(model.enabledScenes, selectedItem: Binding(get: {
            if model.sceneIndex < model.enabledScenes.count {
                model.enabledScenes[model.sceneIndex]
            } else {
                nil
            }
        }, set: { value in
            if let value, let index = model.enabledScenes.firstIndex(of: value) {
                model.sceneIndex = index
            } else {
                model.sceneIndex = 0
            }
        })) {
            Text($0.name)
                .font(.subheadline)
                .frame(
                    width: min(sceneSegmentWidth, (width - 20) / CGFloat(model.enabledScenes.count)),
                    height: segmentHeight
                )
        }
        .onChange(of: model.sceneIndex) { tag in
            model.setSceneId(id: model.enabledScenes[tag].id)
            model.sceneUpdated(attachCamera: true)
        }
        .background(pickerBackgroundColor)
        .foregroundColor(.white)
        .frame(width: min(sceneSegmentWidth * Double(model.enabledScenes.count), width - 20))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
    }
}
