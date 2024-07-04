import SwiftUI

struct StreamOverlayRightSceneSelectorView: View {
    @EnvironmentObject var model: Model

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
                .frame(width: sceneSegmentWidth, height: segmentHeight)
        }
        .onChange(of: model.sceneIndex) { tag in
            model.setSceneId(id: model.enabledScenes[tag].id)
            model.sceneUpdated(store: false)
        }
        .background(pickerBackgroundColor)
        .foregroundColor(.white)
        .frame(width: sceneSegmentWidth * Double(model.enabledScenes.count))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
    }
}
