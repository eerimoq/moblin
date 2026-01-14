import SwiftUI

private struct SceneItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var scene: SettingsScene
    let width: CGFloat

    private func height() -> Double {
        if database.bigButtons {
            return segmentHeightBig
        } else {
            return segmentHeight
        }
    }

    var body: some View {
        ZStack {
            Text(scene.name)
                .font(.subheadline)
                .frame(
                    width: min(sceneSegmentWidth, max((width - 20) / CGFloat(model.enabledScenes.count), 1)),
                    height: height()
                )
            if let quickSwitchGroup = scene.quickSwitchGroup {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        Text(String(quickSwitchGroup))
                            .font(.system(size: 8))
                            .padding([.trailing], 4)
                            .padding([.bottom], 3)
                    }
                }
            }
        }
    }
}

struct StreamOverlayRightSceneSelectorView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneSelector: SceneSelector
    let width: CGFloat

    var body: some View {
        SegmentedPicker(model.enabledScenes, selectedItem: Binding(get: {
            if sceneSelector.sceneIndex < model.enabledScenes.count {
                model.enabledScenes[sceneSelector.sceneIndex]
            } else {
                nil
            }
        }, set: { value in
            if let value, let index = model.enabledScenes.firstIndex(of: value) {
                sceneSelector.sceneIndex = index
            } else {
                sceneSelector.sceneIndex = 0
            }
        })) {
            SceneItemView(database: database, scene: $0, width: width)
        } onLongPress: { index in
            if index < model.enabledScenes.count {
                model.showSceneSettings(scene: model.enabledScenes[index])
            }
        }
        .onChange(of: sceneSelector.sceneIndex) { tag in
            model.selectScene(id: model.enabledScenes[tag].id)
        }
        .background(pickerBackgroundColor)
        .foregroundStyle(.white)
        .frame(width: min(sceneSegmentWidth * Double(model.enabledScenes.count), max(width - 20, 1)))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
    }
}

struct StreamOverlayRightSceneVSelectorView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneSelector: SceneSelector
    let width: CGFloat

    var body: some View {
        SegmentedVPicker(model.enabledScenes.reversed(), selectedItem: Binding(get: {
            if sceneSelector.sceneIndex < model.enabledScenes.count {
                model.enabledScenes[sceneSelector.sceneIndex]
            } else {
                nil
            }
        }, set: { value in
            if let value, let index = model.enabledScenes.firstIndex(of: value) {
                sceneSelector.sceneIndex = index
            } else {
                sceneSelector.sceneIndex = 0
            }
        })) {
            SceneItemView(database: database, scene: $0, width: width)
        } onLongPress: { index in
            if index < model.enabledScenes.count {
                model.showSceneSettings(scene: model.enabledScenes[index])
            }
        }
        .onChange(of: sceneSelector.sceneIndex) { tag in
            model.selectScene(id: model.enabledScenes[tag].id)
        }
        .background(pickerBackgroundColor)
        .foregroundStyle(.white)
        .frame(width: sceneSegmentWidth)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
        .padding([.bottom], 5)
    }
}
