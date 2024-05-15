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

struct FaceViewBeautyShape: View {
    @EnvironmentObject var model: Model
    @State var radius: Float
    @State var scale: Float
    @State var offset: Float

    private var settings: SettingsDebugBeautyFilter {
        return model.database.debug!.beautyFilterSettings!
    }

    var body: some View {
        HStack {
            Text("Radius")
                .foregroundStyle(.white)
            Slider(
                value: $radius,
                in: 0 ... 1,
                step: 0.01,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    model.store()
                }
            )
            .onChange(of: radius) { _ in
                settings.shapeRadius = radius
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
                value: $scale,
                in: 0 ... 1,
                step: 0.01,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    model.store()
                }
            )
            .onChange(of: scale) { _ in
                settings.shapeScale = scale
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
                value: $offset,
                in: 0 ... 1,
                step: 0.01,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    model.store()
                }
            )
            .onChange(of: offset) { _ in
                settings.shapeOffset = offset
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
}

struct FaceViewBeautySmooth: View {
    @EnvironmentObject var model: Model
    @State var amount: Float
    @State var radius: Float

    private var settings: SettingsDebugBeautyFilter {
        return model.database.debug!.beautyFilterSettings!
    }

    var body: some View {
        HStack {
            Text("Amount")
                .foregroundStyle(.white)
            Slider(
                value: $amount,
                in: 0 ... 1,
                step: 0.01,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    model.store()
                }
            )
            .onChange(of: amount) { _ in
                settings.smoothAmount = amount
                ioVideoSmoothAmount = amount
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
                value: $radius,
                in: 5 ... 15,
                step: 0.5,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    model.store()
                }
            )
            .onChange(of: radius) { _ in
                settings.smoothRadius = radius
                ioVideoSmoothRadius = radius
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
}

struct FaceViewBeautyButtons: View {
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
            if model.database.debug!.metalPetalFilters! {
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
                        FaceViewBeautyShape(
                            radius: settings.shapeRadius!,
                            scale: settings.shapeScale!,
                            offset: settings.shapeOffset!
                        )
                    } else if model.showFaceBeautySmooth && model.database.debug!.metalPetalFilters! {
                        FaceViewBeautySmooth(amount: settings.smoothAmount!, radius: settings.smoothRadius!)
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
