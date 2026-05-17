import SwiftUI

struct WidgetMapSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget
    @State var delay: Double
    @State var size: Double

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                widget.map.northUp
            }, set: { value in
                widget.map.northUp = value
                model.resetSelectedScene(changeScene: false)
            })) {
                Text("North up")
            }
        } footer: {
            Text("The map will rotate based of movement direction if disabled.")
        }
        ShortcutSectionView {
            NavigationLink {
                LocationSettingsView(database: model.database,
                                     location: model.database.location,
                                     stream: $model.stream)
            } label: {
                Label("Location", systemImage: "location")
            }
        }
        Section {
            HStack {
                Slider(
                    value: $size,
                    in: 500 ... 10000,
                    step: 100,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        widget.map.size = size
                        model.resetSelectedScene(changeScene: false)
                    }
                )
            }
        } header: {
            Text("Size")
        }
        Section {
            HStack {
                Slider(
                    value: $delay,
                    in: 0 ... 10,
                    step: 0.5,
                    label: {
                        EmptyView()
                    },
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        widget.map.delay = delay
                        model.resetSelectedScene(changeScene: false)
                    }
                )
                Text(String(String(delay)))
                    .frame(width: 35)
            }
        } header: {
            Text("Delay")
        } footer: {
            Text("To show the widget in sync with high latency cameras.")
        }
        WidgetEffectsView(model: model, widget: widget)
    }
}
