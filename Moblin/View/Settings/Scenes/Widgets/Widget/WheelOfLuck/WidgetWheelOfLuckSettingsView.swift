import SwiftUI

let wheelOfLuckOptionWeights = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 40, 60, 80, 100]

private struct OptionView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    @ObservedObject var options: SettingsWidgetWheelOfLuckOption

    private func updateEffect() {
        model.getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: wheelOfLuck)
    }

    private func calcPercent() -> Int {
        return 100 * options.weight / wheelOfLuck.totalWeight
    }

    var body: some View {
        NavigationLink {
            Form {
                TextEditNavigationView(title: "Text", value: options.text) {
                    options.text = $0
                    updateEffect()
                }
                Picker("Weight", selection: $options.weight) {
                    ForEach(wheelOfLuckOptionWeights, id: \.self) {
                        Text(String($0))
                    }
                }
                .onChange(of: options.weight) { _ in
                    wheelOfLuck.updateTotalWeight()
                    updateEffect()
                }
            }
            .navigationTitle("Option")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(options.text)
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
    @State var text: String = ""

    private func updateEffect() {
        model.getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: wheelOfLuck)
    }

    var body: some View {
        Section {
            if wheelOfLuck.advanced {
                ForEach(wheelOfLuck.options) {
                    OptionView(model: model, widget: widget, wheelOfLuck: wheelOfLuck, options: $0)
                }
                .onMove { froms, to in
                    wheelOfLuck.options.move(fromOffsets: froms, toOffset: to)
                    updateEffect()
                }
                .onDelete { offsets in
                    wheelOfLuck.options.remove(atOffsets: offsets)
                    wheelOfLuck.updateTotalWeight()
                    updateEffect()
                }
                .deleteDisabled(wheelOfLuck.options.count < 2)
                CreateButtonView {
                    wheelOfLuck.options.append(SettingsWidgetWheelOfLuckOption())
                    wheelOfLuck.updateTotalWeight()
                    updateEffect()
                }
            } else {
                MultiLineTextFieldView(value: $text)
                    .onChange(of: text) { _ in
                        wheelOfLuck.optionsFromText(text: text)
                        updateEffect()
                    }
                    .onAppear {
                        text = wheelOfLuck.optionsToText()
                    }
            }
        } header: {
            Text("Options")
        }
        Section {
            Toggle("Advanced", isOn: $wheelOfLuck.advanced)
        }
        Section {
            if let effect = model.getWheelOfLuckEffect(id: widget.id) {
                WheelOfLuckWidgetView(model: model, widget: widget, effect: effect, indented: false)
            }
        }
    }
}
