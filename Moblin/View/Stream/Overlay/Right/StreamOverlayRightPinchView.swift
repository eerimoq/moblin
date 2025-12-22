import SwiftUI

struct StreamOverlayRightPinchView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        EffectSlider(title: "PINCH SCALE", range: 0.5 ... 1.0, value: $database.pinchScale)
            .onChange(of: database.pinchScale) { _ in
                model.setPinchScale(scale: database.pinchScale)
            }
    }
}
