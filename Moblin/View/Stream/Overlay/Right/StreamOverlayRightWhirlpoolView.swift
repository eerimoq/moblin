import SwiftUI

struct StreamOverlayRightWhirlpoolView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        EffectSlider(title: "WHIRLPOOL ANGLE", range: .pi / 2 ... .pi * 2, value: $database.whirlpoolAngle)
            .onChange(of: database.whirlpoolAngle) { _ in
                model.setWhirlpoolAngle(angle: database.whirlpoolAngle)
            }
    }
}
