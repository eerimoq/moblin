import SwiftUI

private struct SectorView: View {
    let widget: SettingsWidget
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    @ObservedObject var sector: SettingsWidgetWheelOfLuckSector

    private func calcPercent() -> Int {
        return 100 * sector.weight / wheelOfLuck.totalWeight
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextField("Text", text: $sector.text)
                }
                Section {
                    Picker("Weight", selection: $sector.weight) {
                        ForEach(wheelOfLuckSectorWeights, id: \.self) {
                            Text(String($0))
                        }
                    }
                    .onChange(of: sector.weight) { _ in
                        wheelOfLuck.updateTotalWeight()
                    }
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

struct WidgetWizardWheelOfLuckSettingsView: View {
    let model: Model
    let database: Database
    let widget: SettingsWidget
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            Section {
                ForEach(wheelOfLuck.sectors) {
                    SectorView(widget: widget, wheelOfLuck: wheelOfLuck, sector: $0)
                }
                .onDelete { offsets in
                    wheelOfLuck.sectors.remove(atOffsets: offsets)
                    wheelOfLuck.updateTotalWeight()
                }
                CreateButtonView {
                    wheelOfLuck.sectors.append(SettingsWidgetWheelOfLuckSector())
                    wheelOfLuck.updateTotalWeight()
                }
            } header: {
                Text("Sectors")
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(wheelOfLuck.sectors.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
