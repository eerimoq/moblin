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
    @State var cute: Bool
    @State var blur: Bool
    @State var mouth: Bool
    @State var cuteRadius: Float
    @State var cuteScale: Float
    @State var cuteOffset: Float

    private var settings: SettingsDebugBeautyFilter {
        return model.database.debug!.beautyFilterSettings!
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Spacer()
                if model.showFaceBeauty {
                    HStack {
                        Text("Radius")
                            .foregroundStyle(.white)
                        Slider(
                            value: $cuteRadius,
                            in: 0 ... 1,
                            step: 0.01,
                            onEditingChanged: { begin in
                                guard !begin else {
                                    return
                                }
                                model.store()
                            }
                        )
                        .onChange(of: cuteRadius) { _ in
                            settings.cuteRadius = cuteRadius
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
                            value: $cuteScale,
                            in: 0 ... 1,
                            step: 0.01,
                            onEditingChanged: { begin in
                                guard !begin else {
                                    return
                                }
                                model.store()
                            }
                        )
                        .onChange(of: cuteScale) { _ in
                            settings.cuteScale = cuteScale
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
                            value: $cuteOffset,
                            in: 0 ... 1,
                            step: 0.01,
                            onEditingChanged: { begin in
                                guard !begin else {
                                    return
                                }
                                model.store()
                            }
                        )
                        .onChange(of: cuteOffset) { _ in
                            settings.cuteOffset = cuteOffset
                            model.updateFaceFilterSettings()
                        }
                    }
                    .padding([.top, .bottom], 5)
                    .padding([.leading, .trailing], 7)
                    .frame(width: sliderWidth, height: sliderHeight)
                    .background(backgroundColor)
                    .cornerRadius(7)
                    .padding([.bottom], 5)
                    Button {
                        settings.showCute!.toggle()
                        model.sceneUpdated()
                        model.updateFaceFilterSettings()
                        cute = settings.showCute!
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Cute"),
                            on: cute
                        )
                    }
                    .padding([.bottom], 5)
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
                            on: model.showFaceBeauty || cute
                        )
                    }
                }
            }
            .padding([.trailing], 16)
        }
    }
}
