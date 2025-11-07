import SwiftUI

struct StreamOverlayRightPinchView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("PINCH SCALE")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding([.trailing], 7)
            HStack {
                Slider(
                    value: $database.pinchScale,
                    in: 0.5 ... 1.0,
                    step: 0.01
                )
                .onChange(of: database.pinchScale) { _ in
                    model.setPinchScale(scale: database.pinchScale)
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
