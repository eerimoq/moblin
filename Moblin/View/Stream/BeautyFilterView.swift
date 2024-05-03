import SwiftUI

private let segmentHeight = 40.0
private let zoomSegmentWidth = 50.0
private let sceneSegmentWidth = 70.0
private let cameraButtonWidth = 70.0
private let sliderWidth = 250.0
private let sliderHeight = 40.0
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

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Spacer()
                HStack {
                    Button {
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Mouth"),
                            on: false
                        )
                    }
                    Button {
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Blur"),
                            on: false
                        )
                    }
                    Button {
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Beauty"),
                            on: false
                        )
                    }
                    Button {
                    } label: {
                        BeautyButtonView(
                            title: String(localized: "Enabled"),
                            on: false
                        )
                    }
                }
                .padding([.trailing], 15)
            }
        }
    }
}
