import SwiftUI

private let segmentHeight = 40.0
private let cameraButtonWidth = 70.0
private let pickerBorderColor = Color.gray
private var pickerBackgroundColor = Color.black.opacity(0.6)

private struct BeautyButtonView: View {
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

struct BeautyFilterView: View {
    @EnvironmentObject var model: Model
    @State var enabled: Bool
    @State var beauty: Bool
    @State var blur: Bool
    @State var mouth: Bool

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Spacer()
                HStack {
                    Button {
                        model.database.debug!.beautyFilterSettings!.showMoblin.toggle()
                        model.store()
                        model.updateBeautyFilterSettings()
                        mouth = model.database.debug!.beautyFilterSettings!.showMoblin
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Mouth"),
                            on: mouth
                        )
                    }
                    Button {
                        model.database.debug!.beautyFilterSettings!.showBlur.toggle()
                        model.store()
                        model.updateBeautyFilterSettings()
                        blur = model.database.debug!.beautyFilterSettings!.showBlur
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Blur"),
                            on: blur
                        )
                    }
                    Button {
                        model.database.debug!.beautyFilterSettings!.showCute!.toggle()
                        model.store()
                        model.updateBeautyFilterSettings()
                        beauty = model.database.debug!.beautyFilterSettings!.showCute!
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Beauty"),
                            on: beauty
                        )
                    }
                    Button {
                        model.database.debug!.beautyFilter!.toggle()
                        model.sceneUpdated()
                        enabled = model.database.debug!.beautyFilter!
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Enabled"),
                            on: enabled
                        )
                    }
                }
                .padding([.trailing], 15)
            }
        }
    }
}
