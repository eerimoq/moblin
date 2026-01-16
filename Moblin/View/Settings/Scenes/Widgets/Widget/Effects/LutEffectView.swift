import SwiftUI

struct LutEffectView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var color: SettingsColor
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var lut: SettingsVideoEffectLut

    private func updateWidget() {
        let lut: SettingsColorLut?
        if let id = self.lut.lut {
            lut = model.getLogLutById(id: id)
        } else {
            lut = nil
        }
        model.getWidgetLutEffect(widget, effect)?
            .setLut(lut: lut, imageStorage: model.imageStorage) { title, subTitle in
                model.makeErrorToastMain(title: title, subTitle: subTitle)
            }
    }

    var body: some View {
        Section {
            Picker("", selection: $lut.lut) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(model.allLuts()) { lut in
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
