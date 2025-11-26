import SwiftUI

struct Dewarp360EffectView: View {
    @EnvironmentObject var model: Model
    let widgetId: UUID
    let effectIndex: Int?
    @ObservedObject var dewarp360: SettingsVideoEffectDewarp360

    private func updateWidget() {
        guard let effectIndex, let effect = model.getEffectWithPossibleEffects(id: widgetId) else {
            return
        }
        guard effectIndex < effect.effects.count else {
            return
        }
        guard let effect = effect.effects[effectIndex] as? Dewarp360Effect else {
            return
        }
        effect.setSettings(settings: dewarp360.toSettings())
    }

    var body: some View {
        Section {
            HStack {
                Image(systemName: "arrow.left")
                Slider(
                    value: $dewarp360.pan,
                    in: -180 ... 180,
                    step: 1
                )
                .onChange(of: dewarp360.pan) { _ in
                    updateWidget()
                }
                Image(systemName: "arrow.right")
            }
            HStack {
                Image(systemName: "arrow.down")
                Slider(
                    value: $dewarp360.tilt,
                    in: -90 ... 90,
                    step: 1
                )
                .onChange(of: dewarp360.tilt) { _ in
                    updateWidget()
                }
                Image(systemName: "arrow.up")
            }
            HStack {
                Image(systemName: "minus.magnifyingglass")
                Slider(
                    value: $dewarp360.inverseFieldOfView,
                    in: 30 ... 170,
                    step: 1
                )
                .onChange(of: dewarp360.inverseFieldOfView) { _ in
                    dewarp360.updateZoomFromInverseFieldOfView()
                    updateWidget()
                }
                Image(systemName: "plus.magnifyingglass")
            }
        } header: {
            Text("Pan, tilt and zoom")
        }
    }
}
