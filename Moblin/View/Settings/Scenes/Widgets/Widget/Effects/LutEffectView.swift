import SwiftUI

struct LutEffectView: View {
    let model: Model
    @ObservedObject var color: SettingsColor
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var lut: SettingsVideoEffectLut

    private func updateWidget() {
        model.lutEffectSettingsChanged(widget: widget, effect: effect)
    }

    var body: some View {
        Section {
            Picker("", selection: $lut.lut) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(color.allLuts()) { lut in
                    Text(lut.name)
                        .tag(lut.id as UUID?)
                }
            }
            .onChange(of: lut.lut) { _ in
                updateWidget()
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("LUT")
        }
        ShortcutSectionView {
            NavigationLink {
                CameraSettingsLutsView(color: color)
            } label: {
                Label("LUTs", systemImage: "camera")
            }
        }
    }
}
