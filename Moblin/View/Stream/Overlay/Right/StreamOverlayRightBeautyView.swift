import SwiftUI

struct StreamOverlayRightBeautyView: View {
    let model: Model
    @ObservedObject var database: Database

    private func setSettings() {
        model.beautyEffect.setSettings(amount: database.beautyStrength,
                                       radius: database.beautyRadius)
    }

    var body: some View {
        EffectSlider(title: "BEAUTY RADIUS", range: 5 ... 20, value: $database.beautyRadius)
            .onChange(of: database.beautyRadius) { _ in
                setSettings()
            }
        EffectSlider(title: "BEAUTY STRENGTH", range: 0 ... 1, value: $database.beautyStrength)
            .onChange(of: database.beautyStrength) { _ in
                setSettings()
            }
    }
}
