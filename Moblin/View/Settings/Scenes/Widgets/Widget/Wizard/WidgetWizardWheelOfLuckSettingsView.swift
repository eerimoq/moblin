import SwiftUI

private struct OptionView: View {
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    @ObservedObject var option: SettingsWidgetWheelOfLuckOption

    private func calcPercent() -> Int {
        return 100 * option.weight / wheelOfLuck.totalWeight
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextField("Text", text: $option.text)
                }
                Section {
                    Picker("Weight", selection: $option.weight) {
                        ForEach(wheelOfLuckOptionWeights, id: \.self) {
                            Text(String($0))
                        }
                    }
                    .onChange(of: option.weight) { _ in
                        wheelOfLuck.updateTotalWeight()
                    }
                }
            }
            .navigationTitle("Option")
        } label: {
            HStack {
                Text(option.text)
                Spacer()
                Text("\(calcPercent())%")
            }
        }
    }
}

struct WidgetWizardWheelOfLuckSettingsView: View {
    let model: Model
    let database: Database
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    let createWidgetWizard: CreateWidgetWizard
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            Section {
                ForEach(wheelOfLuck.options) {
                    OptionView(wheelOfLuck: wheelOfLuck, option: $0)
                }
                .onDelete { offsets in
                    wheelOfLuck.options.remove(atOffsets: offsets)
                    wheelOfLuck.updateTotalWeight()
                }
                CreateButtonView {
                    wheelOfLuck.options.append(SettingsWidgetWheelOfLuckOption())
                    wheelOfLuck.updateTotalWeight()
                }
            } header: {
                Text("Options")
            }
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(wheelOfLuck.options.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
