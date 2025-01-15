import SwiftUI

private let sliderWidth = 250.0

struct StreamOverlayRightPixellateView: View {
    @EnvironmentObject var model: Model
    @State var strength: Float

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("PIXELLATE STRENGTH")
                .font(.footnote)
                .foregroundColor(.white)
                .padding([.trailing], 7)
            HStack {
                Slider(
                    value: $strength,
                    in: 0 ... 1,
                    step: 0.01
                )
                .onChange(of: strength) { value in
                    model.database.pixellateStrength = value
                    model.setPixellateStrength(strength: value)
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
