import SwiftUI

struct StreamOverlayRightPixellateView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("PIXELLATE STRENGTH")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding([.trailing], 7)
            HStack {
                Slider(
                    value: $database.pixellateStrength,
                    in: 0 ... 1,
                    step: 0.01
                )
                .onChange(of: database.pixellateStrength) { _ in
                    model.setPixellateStrength(strength: database.pixellateStrength)
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
