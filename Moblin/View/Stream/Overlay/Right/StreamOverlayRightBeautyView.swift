import SwiftUI

private struct SmoothView: View {
    let model: Model
    @ObservedObject var beauty: SettingsBeauty

    private func setSettings() {
        model.beautyEffect.setSmoothSettings(radius: beauty.smoothRadius,
                                             strength: beauty.smoothStrength)
    }

    var body: some View {
        EffectSlider(title: "RADIUS", range: 5 ... 20, value: $beauty.smoothRadius)
            .onChange(of: beauty.smoothRadius) { _ in
                setSettings()
            }
        EffectSlider(title: "STRENGTH", range: 0 ... 1, value: $beauty.smoothStrength)
            .onChange(of: beauty.smoothStrength) { _ in
                setSettings()
            }
    }
}

private struct ShapeView: View {
    let model: Model
    @ObservedObject var beauty: SettingsBeauty

    private func setSettings() {
        model.beautyEffect.setShapeSettings(position: beauty.shapePosition,
                                            radius: beauty.shapeRadius,
                                            strength: beauty.shapeStrength)
    }

    var body: some View {
        EffectSlider(title: "POSITION", range: 0 ... 1, value: $beauty.shapePosition)
            .onChange(of: beauty.shapePosition) { _ in
                setSettings()
            }
        EffectSlider(title: "RADIUS", range: 0 ... 1, value: $beauty.shapeRadius)
            .onChange(of: beauty.shapeRadius) { _ in
                setSettings()
            }
        EffectSlider(title: "STRENGTH", range: 0 ... 1, value: $beauty.shapeStrength)
            .onChange(of: beauty.shapeStrength) { _ in
                setSettings()
            }
    }
}

struct StreamOverlayRightBeautyView: View {
    let model: Model
    @ObservedObject var beauty: SettingsBeauty

    var body: some View {
        switch beauty.settings {
        case .smooth:
            SmoothView(model: model, beauty: beauty)
        case .shape:
            ShapeView(model: model, beauty: beauty)
        }
        Toggle(isOn: $beauty.enabled) {
            Picker("", selection: $beauty.settings) {
                ForEach(SettingsBeautySettings.allCases, id: \.self) {
                    Text($0.toString())
                }
            }
            .tint(.white)
        }
        .onChange(of: beauty.enabled) { _ in
            model.updateBeautyButtonState()
            model.sceneUpdated(updateRemoteScene: false)
        }
        .padding([.trailing], 10)
        .fixedSize()
        .frame(height: segmentHeight)
        .background(pickerBackgroundColor)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor, lineWidth: 1)
        )
    }
}
