import SwiftUI

struct LutEffectView: View {
    let model: Model
    @ObservedObject var color: SettingsColor
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var lut: SettingsVideoEffectLut

    private func updateWidget() {
        let lut = model.getLogLutById(id: lut.lut)
        model.getWidgetLutEffect(widget, effect)?.setLut(lut: lut, imageStorage: model.imageStorage) {
            model.makeErrorToast(title: $0, subTitle: $1)
        }
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
