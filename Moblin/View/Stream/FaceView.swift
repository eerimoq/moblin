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
            .foregroundColor(.white)
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
    @ObservedObject var face: SettingsDebugFace
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
