import SwiftUI

struct StreamOverlayRightTorchView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        EffectSlider(title: "TORCH BRIGHTNESS", range: 0.01 ... 1, value: $database.torchLevel)
            .onChange(of: database.torchLevel) { _ in
                model.setTorchLevel(level: database.torchLevel)
            }
    }
}
