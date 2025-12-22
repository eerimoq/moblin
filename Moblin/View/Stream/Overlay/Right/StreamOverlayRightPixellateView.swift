import SwiftUI

struct StreamOverlayRightPixellateView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        EffectSlider(title: "PIXELLATE STRENGTH", range: 0 ... 1, value: $database.pixellateStrength)
            .onChange(of: database.pixellateStrength) { _ in
                model.setPixellateStrength(strength: database.pixellateStrength)
            }
    }
}
