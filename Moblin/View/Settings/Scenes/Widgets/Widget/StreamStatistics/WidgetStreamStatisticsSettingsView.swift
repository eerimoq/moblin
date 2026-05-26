import SwiftUI

struct WidgetStreamStatisticsSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var streamStatistics: SettingsWidgetStreamStatistics

    private func setEffectSettings() {
        model.getStreamStatisticsEffect(id: widget.id)?.setSettings(settings: streamStatistics)
    }

    var body: some View {
        Section {
            ForEach(streamStatistics.items) { item in
                Toggle(isOn: Binding(
                    get: { item.show },
                    set: { newValue in
                        item.show = newValue
                        setEffectSettings()
                    }
                )) {
                    HStack {
                        Image(systemName: item.type.systemImage())
                            .frame(width: 20)
                        Text(item.label)
                    }
                }
            }
        } header: {
            Text("Items")
        } footer: {
            Text("Toggle which event types are shown in the widget.")
        }
        Section {
            HStack {
                Text("Font size")
                Slider(value: $streamStatistics.fontSize, in: 10 ... 80, step: 1)
                Text(String(Int(streamStatistics.fontSize)))
                    .frame(width: 35)
            }
            .onChange(of: streamStatistics.fontSize) { _ in
                setEffectSettings()
            }
            HStack {
                Text("Width")
                Slider(value: $streamStatistics.width, in: 5 ... 80, step: 1)
            }
            .onChange(of: streamStatistics.width) { _ in
                setEffectSettings()
            }
        } header: {
            Text("Appearance")
        }
        Section {
            ColorPicker("Background", selection: $streamStatistics.backgroundColorColor, supportsOpacity: true)
                .onChange(of: streamStatistics.backgroundColorColor) { _ in
                    guard let color = streamStatistics.backgroundColorColor.toRgb() else {
                        return
                    }
                    streamStatistics.backgroundColor = color
                    setEffectSettings()
                }
            ColorPicker("Text", selection: $streamStatistics.foregroundColorColor, supportsOpacity: false)
                .onChange(of: streamStatistics.foregroundColorColor) { _ in
                    guard let color = streamStatistics.foregroundColorColor.toRgb() else {
                        return
                    }
                    streamStatistics.foregroundColor = color
                    setEffectSettings()
                }
        } header: {
            Text("Colors")
        }
        Section {
            Button {
                model.resetAllStreamStatisticsCounts()
            } label: {
                HCenter {
                    Text("Reset counts")
                }
            }
        } header: {
            Text("Controls")
        }
    }
}
