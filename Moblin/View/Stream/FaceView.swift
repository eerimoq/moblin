import SwiftUI

private let segmentHeight = 40.0
private let sliderWidth = 300.0
private let sliderHeight = 40.0
private let cameraButtonWidth = 70.0
private let pickerBorderColor = Color.gray
private var pickerBackgroundColor = Color.black.opacity(0.6)

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
                    .stroke(on ? .white : pickerBorderColor)
            )
    }
}

struct FaceView: View {
    @EnvironmentObject var model: Model
    @State var crop: Bool
    @State var beauty: Bool
    @State var blur: Bool
    @State var mouth: Bool
    @State var shapeRadius: Float
    @State var shapeScale: Float
    @State var shapeOffset: Float
    @State var smoothAmount: Float
    @State var smoothRadius: Float

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
                        HStack {
                            Text("Radius")
                                .foregroundStyle(.white)
                            Slider(
                                value: $shapeRadius,
                                in: 0 ... 1,
                                step: 0.01,
                                onEditingChanged: { begin in
                                    guard !begin else {
                                        return
                                    }
                                    model.store()
                                }
                            )
                            .onChange(of: shapeRadius) { _ in
                                settings.shapeRadius = shapeRadius
                                model.updateFaceFilterSettings()
                            }
                        }
                        .padding([.top, .bottom], 5)
                        .padding([.leading, .trailing], 7)
                        .frame(width: sliderWidth, height: sliderHeight)
                        .background(backgroundColor)
                        .cornerRadius(7)
                        .padding([.bottom], 5)
                        HStack {
                            Text("Scale")
                                .foregroundStyle(.white)
                            Slider(
                                value: $shapeScale,
                                in: 0 ... 1,
                                step: 0.01,
                                onEditingChanged: { begin in
                                    guard !begin else {
                                        return
                                    }
                                    model.store()
                                }
                            )
                            .onChange(of: shapeScale) { _ in
                                settings.shapeScale = shapeScale
                                model.updateFaceFilterSettings()
                            }
                        }
                        .padding([.top, .bottom], 5)
                        .padding([.leading, .trailing], 7)
                        .frame(width: sliderWidth, height: sliderHeight)
                        .background(backgroundColor)
                        .cornerRadius(7)
                        .padding([.bottom], 5)
                        HStack {
                            Text("Offset")
                                .foregroundStyle(.white)
                            Slider(
                                value: $shapeOffset,
                                in: 0 ... 1,
                                step: 0.01,
                                onEditingChanged: { begin in
                                    guard !begin else {
                                        return
                                    }
                                    model.store()
                                }
                            )
                            .onChange(of: shapeOffset) { _ in
                                settings.shapeOffset = shapeOffset
                                model.updateFaceFilterSettings()
                            }
                        }
                        .padding([.top, .bottom], 5)
                        .padding([.leading, .trailing], 7)
                        .frame(width: sliderWidth, height: sliderHeight)
                        .background(backgroundColor)
                        .cornerRadius(7)
                        .padding([.bottom], 5)
                    } else if model.showFaceBeautySmooth && model.database.debug!.metalPetalFilters! {
                        HStack {
                            Text("Amount")
                                .foregroundStyle(.white)
                            Slider(
                                value: $smoothAmount,
                                in: 0 ... 1,
                                step: 0.01,
                                onEditingChanged: { begin in
                                    guard !begin else {
                                        return
                                    }
                                    model.store()
                                }
                            )
                            .onChange(of: smoothAmount) { _ in
                                settings.smoothAmount = smoothAmount
                                ioVideoSmoothAmount = smoothAmount
                                model.updateFaceFilterSettings()
                            }
                        }
                        .padding([.top, .bottom], 5)
                        .padding([.leading, .trailing], 7)
                        .frame(width: sliderWidth, height: sliderHeight)
                        .background(backgroundColor)
                        .cornerRadius(7)
                        .padding([.bottom], 5)
                        HStack {
                            Text("Radius")
                                .foregroundStyle(.white)
                            Slider(
                                value: $smoothRadius,
                                in: 5 ... 15,
                                step: 0.5,
                                onEditingChanged: { begin in
                                    guard !begin else {
                                        return
                                    }
                                    model.store()
                                }
                            )
                            .onChange(of: smoothRadius) { _ in
                                settings.smoothRadius = smoothRadius
                                ioVideoSmoothRadius = smoothRadius
                                model.updateFaceFilterSettings()
                            }
                        }
                        .padding([.top, .bottom], 5)
                        .padding([.leading, .trailing], 7)
                        .frame(width: sliderWidth, height: sliderHeight)
                        .background(backgroundColor)
                        .cornerRadius(7)
                        .padding([.bottom], 5)
                    }
                    HStack {
                        Button {
                            model.showFaceBeautyShape.toggle()
                            model.showFaceBeautySmooth = false
                        } label: {
                            FaceButtonView(
                                title: String(localized: "Shape"),
                                on: model.showFaceBeautyShape
                            )
                        }
                        .padding([.bottom], 5)
                        if model.database.debug!.metalPetalFilters! {
                            Button {
                                model.showFaceBeautyShape = false
                                model.showFaceBeautySmooth.toggle()
                            } label: {
                                FaceButtonView(
                                    title: String(localized: "Smooth"),
                                    on: model.showFaceBeautySmooth
                                )
                            }
                            .padding([.bottom], 5)
                        }
                        Button {
                            model.database.debug!.beautyFilterSettings!.showBeauty!.toggle()
                            model.sceneUpdated()
                            model.updateFaceFilterSettings()
                            beauty = model.database.debug!.beautyFilterSettings!.showBeauty!
                        } label: {
                            FaceButtonView(
                                title: String(localized: "Enabled"),
                                on: beauty
                            )
                        }
                        .padding([.bottom], 5)
                    }
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
