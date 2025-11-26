import SwiftUI

struct StreamOverlayRightWhirlpoolView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("WHIRLPOOL ANGLE")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding([.trailing], 7)
            HStack {
                Slider(
                    value: $database.whirlpoolAngle,
                    in: .pi / 2 ... .pi * 2,
                    step: 0.01
                )
                .onChange(of: database.whirlpoolAngle) { _ in
                    model.setWhirlpoolAngle(angle: database.whirlpoolAngle)
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
}
