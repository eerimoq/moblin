import SwiftUI

private struct FaceButtonView: View {
    let title: LocalizedStringKey
    @Binding var on: Bool
    let height: Double

    var body: some View {
        Text(title)
            .font(.subheadline)
            .frame(width: cameraButtonWidth, height: height)
            .background(pickerBackgroundColor)
            .foregroundStyle(.white)
            .cornerRadius(7)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(on ? .white : pickerBorderColor, lineWidth: on ? 1.5 : 1)
            )
    }
}

struct EffectSlider: View {
    let title: LocalizedStringKey
    let range: ClosedRange<Float>
    @Binding var value: Float

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding([.trailing], 7)
            HStack {
                Slider(value: $value, in: range, step: 0.01)
            }
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 7)
            .frame(width: sliderWidth, height: sliderHeight)
            .background(backgroundColor)
            .cornerRadius(7)
            .padding([.bottom], 5)
        }
    }
}

struct FaceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var debug: SettingsDebug
    @ObservedObject var face: SettingsFace
    @ObservedObject var show: Show

    private func height() -> Double {
        if database.bigButtons {
            return segmentHeightBig
        } else {
            return segmentHeight
        }
    }

    var body: some View {
        let height = height()
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                Spacer()
                if face.showBlur || face.showBlurBackground {
                    switch face.privacyMode {
                    case .blur:
                        EffectSlider(title: "BLUR STRENGTH", range: 0.1 ... 1, value: $face.blurStrength)
                            .onChange(of: face.blurStrength) { _ in
                                model.updateFaceFilterSettings()
                            }
                    case .pixellate:
                        EffectSlider(title: "PIXELLATE STRENGTH", range: 0 ... 1, value: $face.pixellateStrength)
                            .onChange(of: face.pixellateStrength) { _ in
                                model.updateFaceFilterSettings()
                            }
                    }
                    HStack(spacing: 0) {
                        Text("Mode")
                            .foregroundStyle(.white)
                            .padding([.leading], 10)
                        Spacer()
                        Picker("", selection: $face.privacyMode) {
                            ForEach(SettingsFacePrivacyMode.allCases, id: \.self) {
                                Text($0.toString())
                            }
                        }
                        .tint(.white)
                        .onChange(of: face.privacyMode) { _ in
                            model.updateFaceFilterSettings()
                        }
                    }
                    .frame(width: 226, height: height)
                    .background(pickerBackgroundColor)
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(pickerBorderColor, lineWidth: 1)
                    )
                }
                HStack {
                    Button {
                        face.showMoblin.toggle()
                        model.sceneUpdated(updateRemoteScene: false)
                        model.updateFaceFilterSettings()
                        model.updateFaceFilterButtonState()
                    } label: {
                        FaceButtonView(title: "Mouth", on: $face.showMoblin, height: height)
                    }
                    Button {
                        model.toggleBlurFaces()
                    } label: {
                        FaceButtonView(title: "Face", on: $face.showBlur, height: height)
                    }
                    Button {
                        model.togglePrivacy()
                    } label: {
                        FaceButtonView(title: "Privacy", on: $face.showBlurBackground, height: height)
                    }
                }
            }
            .padding([.trailing], 16)
        }
    }
}
