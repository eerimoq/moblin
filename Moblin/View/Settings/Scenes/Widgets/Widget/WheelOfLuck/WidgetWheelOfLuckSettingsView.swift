import SwiftUI

let wheelOfLuckSectorWeights = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 40, 60, 80, 100]

private struct SectorView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    @ObservedObject var sector: SettingsWidgetWheelOfLuckSector

    private func updateEffect() {
        model.getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: wheelOfLuck)
    }

    private func calcPercent() -> Int {
        return 100 * sector.weight / wheelOfLuck.totalWeight
    }

    var body: some View {
        NavigationLink {
            Form {
                TextEditNavigationView(title: "Text", value: sector.text) {
                    sector.text = $0
                    updateEffect()
                }
                Picker("Weight", selection: $sector.weight) {
                    ForEach(wheelOfLuckSectorWeights, id: \.self) {
                        Text(String($0))
                    }
                }
                .onChange(of: sector.weight) { _ in
                    wheelOfLuck.updateTotalWeight()
                    updateEffect()
                }
            }
            .navigationTitle("Sector")
        } label: {
            HStack {
                Text(sector.text)
                Spacer()
                Text("\(calcPercent())%")
            }
        }
    }
}

struct WidgetWheelOfLuckSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck

    private func updateEffect() {
        model.getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: wheelOfLuck)
    }

    var body: some View {
        Section {
            ForEach(wheelOfLuck.sectors) {
                SectorView(model: model, widget: widget, wheelOfLuck: wheelOfLuck, sector: $0)
            }
            .onDelete { offsets in
                wheelOfLuck.sectors.remove(atOffsets: offsets)
                wheelOfLuck.updateTotalWeight()
                updateEffect()
            }
            CreateButtonView {
                wheelOfLuck.sectors.append(SettingsWidgetWheelOfLuckSector())
                wheelOfLuck.updateTotalWeight()
                updateEffect()
            }
        } header: {
            Text("Sectors")
        }
        Section {
            if let effect = model.getWheelOfLuckEffect(id: widget.id) {
                WheelOfLuckWidgetView(effect: effect, indented: false)
            }
        }
    }
}
