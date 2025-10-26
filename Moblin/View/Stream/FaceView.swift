import SwiftUI

private let faceSliderWidth = 200.0

private struct FaceButtonView: View {
    let title: String
    let on: Bool
    let height: Double

    var body: some View {
        Text(title)
            .font(.subheadline)
            .frame(width: cameraButtonWidth, height: height)
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
    let name: String
    @State var value: Float
    let range: ClosedRange<Float>
    let step: Float
    let onChange: (Float) -> Void

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
                label: {
                    EmptyView()
                },
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
            .frame(width: faceSliderWidth, height: sliderHeight)
            .background(backgroundColor)
            .cornerRadius(7)
        }
        .padding([.bottom], 5)
    }
}

private struct FaceViewBeautyShape: View {
    @EnvironmentObject var model: Model

    private var settings: SettingsDebugBeautyFilter {
        return model.database.debug.beautyFilterSettings
    }

    var body: some View {
        FaceViewSlider(
            name: String(localized: "POSITION"),
            value: settings.shapeOffset,
            range: 0 ... 1,
            step: 0.01,
            onChange: { offset in
                settings.shapeOffset = offset
                model.updateFaceFilterSettings()
            }
        )
        FaceViewSlider(
            name: String(localized: "RADIUS"),
            value: settings.shapeRadius,
            range: 0 ... 1,
            step: 0.01,
            onChange: { radius in
                settings.shapeRadius = radius
                model.updateFaceFilterSettings()
            }
        )
        FaceViewSlider(
            name: String(localized: "STRENGTH"),
            value: settings.shapeScale,
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
        return model.database.debug.beautyFilterSettings
    }

    var body: some View {
        FaceViewSlider(
            name: String(localized: "RADIUS"),
            value: settings.smoothRadius,
            range: 5 ... 20,
            step: 0.5,
            onChange: { radius in
                settings.smoothRadius = radius
                model.updateFaceFilterSettings()
            }
        )
        FaceViewSlider(
            name: String(localized: "STRENGTH"),
            value: settings.smoothAmount,
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
    @ObservedObject var show: Show
    @Binding var beauty: Bool
    let height: Double

    var body: some View {
        HStack {
            Button {
                show.faceBeautyShape.toggle()
                show.faceBeautySmooth = false
                model.updateFaceFilterButtonState()
            } label: {
                FaceButtonView(title: String(localized: "Shape"),
                               on: show.faceBeautyShape,
                               height: height)
            }
            if false {
                Button {
                    show.faceBeautyShape = false
                    show.faceBeautySmooth.toggle()
                    model.updateFaceFilterButtonState()
                } label: {
                    FaceButtonView(title: String(localized: "Smooth"),
                                   on: show.faceBeautySmooth,
                                   height: height)
                }
            }
            Button {
                model.database.debug.beautyFilterSettings.showBeauty.toggle()
                model.sceneUpdated(updateRemoteScene: false)
                model.updateFaceFilterSettings()
                beauty = model.database.debug.beautyFilterSettings.showBeauty
                model.updateFaceFilterButtonState()
            } label: {
                FaceButtonView(title: String(localized: "Enabled"),
                               on: beauty,
                               height: height)
            }
        }
        .padding([.bottom], 5)
    }
}

struct FaceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var debug: SettingsDebug
    @ObservedObject var settings: SettingsDebugBeautyFilter
    @ObservedObject var show: Show

    private func height() -> Double {
        if database.bigButtons {
            return segmentHeightBig
        } else {
            return segmentHeight
        }
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Spacer()
                if show.faceBeauty {
                    if show.faceBeautyShape {
                        FaceViewBeautyShape()
                    } else if false {
                        FaceViewBeautySmooth()
                    }
                    FaceViewBeautyButtons(show: show, beauty: $settings.showBeauty, height: height())
                }
                HStack {
                    Button {
                        debug.beautyFilter.toggle()
                        model.sceneUpdated(updateRemoteScene: false)
                        model.updateFaceFilterSettings()
                        model.updateFaceFilterButtonState()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Crop"),
                            on: debug.beautyFilter,
                            height: height()
                        )
                    }
                    Button {
                        settings.showMoblin.toggle()
                        model.sceneUpdated(updateRemoteScene: false)
                        model.updateFaceFilterSettings()
                        model.updateFaceFilterButtonState()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Mouth"),
                            on: settings.showMoblin,
                            height: height()
                        )
                    }
                    Button {
                        settings.showBlur.toggle()
                        model.sceneUpdated(updateRemoteScene: false)
                        model.updateFaceFilterSettings()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Blur"),
                            on: settings.showBlur,
                            height: height()
                        )
                    }
                    Button {
                        settings.showBlurBackground.toggle()
                        model.sceneUpdated(updateRemoteScene: false)
                        model.updateFaceFilterSettings()
                        model.updateFaceFilterButtonState()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Privacy"),
                            on: settings.showBlurBackground,
                            height: height()
                        )
                    }
                    Button {
                        show.faceBeauty.toggle()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Beauty"),
                            on: debug.beautyFilter || show.faceBeauty,
                            height: height()
                        )
                    }
                }
            }
            .padding([.trailing], 16)
        }
    }
}
