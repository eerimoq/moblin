import SwiftUI

private struct FaceButtonView: View {
    let title: String
    let on: Bool
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
        HStack {
            Spacer()
            VStack(alignment: .trailing) {
                Spacer()
                if face.showBlur || face.showBlurBackground {
                    switch face.privacyMode {
                    case .blur:
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("BLUR STRENGTH")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding([.trailing], 7)
                            HStack {
                                Slider(
                                    value: $face.blurStrength,
                                    in: 0.15 ... 1,
                                    step: 0.01
                                )
                                .onChange(of: face.blurStrength) { _ in
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
                    case .pixellate:
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("PIXELLATE STRENGTH")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding([.trailing], 7)
                            HStack {
                                Slider(
                                    value: $face.pixellateStrength,
                                    in: 0 ... 1,
                                    step: 0.01
                                )
                                .onChange(of: face.pixellateStrength) { _ in
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
                    .frame(width: 226, height: height())
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
                        FaceButtonView(
                            title: String(localized: "Mouth"),
                            on: face.showMoblin,
                            height: height()
                        )
                    }
                    Button {
                        face.showBlur.toggle()
                        model.sceneUpdated(updateRemoteScene: false)
                        model.updateFaceFilterSettings()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Blur"),
                            on: face.showBlur,
                            height: height()
                        )
                    }
                    Button {
                        face.showBlurBackground.toggle()
                        model.sceneUpdated(updateRemoteScene: false)
                        model.updateFaceFilterSettings()
                        model.updateFaceFilterButtonState()
                    } label: {
                        FaceButtonView(
                            title: String(localized: "Privacy"),
                            on: face.showBlurBackground,
                            height: height()
                        )
                    }
                }
            }
            .padding([.trailing], 16)
        }
    }
}
