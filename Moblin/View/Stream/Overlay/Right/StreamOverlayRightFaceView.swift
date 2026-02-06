import SwiftUI

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

struct StreamOverlayRightFaceView: View {
    let model: Model
    @ObservedObject var face: SettingsFace

    var body: some View {
        if face.blurFaces || face.blurText || face.blurBackground {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Spacer()
                    switch face.privacyMode {
                    case .blur:
                        EffectSlider(title: "BLUR STRENGTH", range: 0.1 ... 1, value: $face.blurStrength)
                            .onChange(of: face.blurStrength) { _ in
                                model.updateFaceFilterSettings()
                            }
                    case .pixellate:
                        EffectSlider(
                            title: "PIXELLATE STRENGTH",
                            range: 0 ... 1,
                            value: $face.pixellateStrength
                        )
                        .onChange(of: face.pixellateStrength) { _ in
                            model.updateFaceFilterSettings()
                        }
                    }
                    Picker("", selection: $face.privacyMode) {
                        ForEach(SettingsFacePrivacyMode.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    .tint(.white)
                    .onChange(of: face.privacyMode) { _ in
                        model.updateFaceFilterSettings()
                    }
                    .frame(height: segmentHeight)
                    .background(pickerBackgroundColor)
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(pickerBorderColor, lineWidth: 1)
                    )
                }
            }
            .padding([.bottom], 5)
        }
    }
}
