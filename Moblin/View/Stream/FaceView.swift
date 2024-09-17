import SwiftUI

private let sliderWidth = 200.0

private struct FaceButtonView: View {
    var title: String
    var on: Bool

    var body: some View {
        Text(title)
            .font(.subheadline)
            .frame(width: cameraButtonWidth, height: segmentHeight)
            .background(pickerBackgroundColor)
            .foregroundColor(.white)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(on ? .white : pickerBorderColor, lineWidth: on ? 1.5 : 1)
            )
    }
}

private struct FaceViewSlider: View {
    @EnvironmentObject var model: Model
    var name: String
    @State var value: Float
    var range: ClosedRange<Float>
    var step: Float
    var onChange: (Float) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(name)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding([.trailing], 7)
            Slider(
                value: $value,
                in: range,
                step: step,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                }
            )
            .onChange(of: value) { _ in
                onChange(value)
            }
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 7)
            .frame(width: sliderWidth, height: sliderHeight)
            .background(backgroundColor)
            .cornerRadius(7)
        }
        .padding([.bottom], 5)
    }
}

private struct FaceViewBeautyShape: View {
    @EnvironmentObject var model: Model

    private var settings: SettingsDebugBeautyFilter {
        return model.database.debug!.beautyFilterSettings!
    }

    var body: some View {
        FaceViewSlider(
            name: String(localized: "POSITION"),
            value: settings.shapeOffset!,
            range: 0 ... 1,
            step: 0.01,
            onChange: { offset in
                settings.shapeOffset = offset
                model.updateFaceFilterSettings()
            }
        )
        FaceViewSlider(
            name: String(localized: "RADIUS"),
            value: settings.shapeRadius!,
            range: 0 ... 1,
            step: 0.01,
            onChange: { radius in
                settings.shapeRadius = radius
                model.updateFaceFilterSettings()
            }
        )
        FaceViewSlider(
            name: String(localized: "STRENGTH"),
            value: settings.shapeScale!,
            range: 0 ... 1,
            step: 0.01,
            onChange: { scale in
                settings.shapeScale = scale
                model.updateFaceFilterSettings()
            }
        )
    }
}

private struct FaceViewBeautySmooth: View {
    @EnvironmentObject var model: Model

    private var settings: SettingsDebugBeautyFilter {
        return model.database.debug!.beautyFilterSettings!
    }

    var body: some View {
        FaceViewSlider(
            name: String(localized: "RADIUS"),
            value: settings.smoothRadius!,
            range: 5 ... 20,
            step: 0.5,
            onChange: { radius in
                settings.smoothRadius = radius
                model.updateFaceFilterSettings()
            }
        )
        FaceViewSlider(
            name: String(localized: "STRENGTH"),
            value: settings.smoothAmount!,
            range: 0 ... 1,
            step: 0.01,
            onChange: { amount in
                settings.smoothAmount = amount
                model.updateFaceFilterSettings()
            }
        )
    }
}

private struct FaceViewBeautyButtons: View {
    @EnvironmentObject var model: Model
    @Binding var beauty: Bool

    var body: some View {
        HStack {
            Button {
                model.showFaceBeautyShape.toggle()
                model.showFaceBeautySmooth = false
            } label: {
                FaceButtonView(title: String(localized: "Shape"), on: model.showFaceBeautyShape)
            }
            if model.database.color!.space != .appleLog && model.database.debug!.metalPetalFilters! {
                Button {
                    model.showFaceBeautyShape = false
                    model.showFaceBeautySmooth.toggle()
                } label: {
                    FaceButtonView(title: String(localized: "Smooth"), on: model.showFaceBeautySmooth)
                }
            }
            Button {
                model.database.debug!.beautyFilterSettings!.showBeauty!.toggle()
                model.sceneUpdated()
                model.updateFaceFilterSettings()
                beauty = model.database.debug!.beautyFilterSettings!.showBeauty!
            } label: {
                FaceButtonView(title: String(localized: "Enabled"), on: beauty)
            }
        }
        .padding([.bottom], 5)
    }
}

struct FaceView: View {
    @EnvironmentObject var model: Model
    @State var crop: Bool
    @State var beauty: Bool
    @State var blur: Bool
    @State var mouth: Bool

    private var settings: SettingsDebugBeautyFilter {
        return model.database.debug!.beautyFilterSettings!
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Spacer()
                if model.showFaceBeauty {
                    if model.showFaceBeautyShape {
                        FaceViewBeautyShape()
                    } else if model.showFaceBeautySmooth && model.database.color!
                        .space != .appleLog && model.database.debug!.metalPetalFilters!
                    {
                        FaceViewBeautySmooth()
                    }
                    FaceViewBeautyButtons(beauty: $beauty)
                }
                HStack {
                    Button {
                        model.database.debug!.beautyFilter!.toggle()
                        model.sceneUpdated()
                        model.updateFaceFilterSettings()
                        crop = model.database.debug!.beautyFilter!
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Crop"),
                            on: crop
                        )
                    }
                    Button {
                        settings.showMoblin.toggle()
                        model.sceneUpdated()
                        model.updateFaceFilterSettings()
                        mouth = settings.showMoblin
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Mouth"),
                            on: mouth
                        )
                    }
                    Button {
                        settings.showBlur.toggle()
                        model.sceneUpdated()
                        model.updateFaceFilterSettings()
                        blur = settings.showBlur
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Blur"),
                            on: blur
                        )
                    }
                    Button {
                        model.showFaceBeauty.toggle()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Beauty"),
                            on: beauty || model.showFaceBeauty
                        )
                    }
                }
            }
            .padding([.trailing], 16)
        }
    }
}
