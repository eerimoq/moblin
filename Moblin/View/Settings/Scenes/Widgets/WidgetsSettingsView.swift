import SwiftUI

private struct WidgetsSettingsItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        NavigationLink {
            WidgetSettingsView(widget: widget)
        } label: {
            Toggle(isOn: $widget.enabled) {
                HStack {
                    DraggableItemPrefixView()
                    IconAndTextView(
                        image: widgetImage(widget: widget),
                        text: widget.name,
                        longDivider: true
                    )
                    Spacer()
                }
            }
            .onChange(of: widget.enabled) { _ in
                model.sceneUpdated(attachCamera: model.isCaptureDeviceVideoSoureWidget(widget: widget))
            }
        }
    }
}

struct WidgetsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Section {
            ForEach(database.widgets) { widget in
                WidgetsSettingsItemView(widget: widget)
            }
            .onMove(perform: { froms, to in
                database.widgets.move(fromOffsets: froms, toOffset: to)
            })
            .onDelete(perform: { offsets in
                database.widgets.remove(atOffsets: offsets)
                model.removeDeadWidgetsFromScenes()
                model.resetSelectedScene()
            })
            CreateButtonView {
                database.widgets.append(SettingsWidget(name: String(localized: "My widget")))
                model.fixAlertMedias()
            }
        } header: {
            Text("Widgets")
        } footer: {
            VStack(alignment: .leading) {
                Text("A widget can be used in zero or more scenes.")
                Text("")
                SwipeLeftToDeleteHelpView(kind: String(localized: "a widget"))
            }
        }
    }
}
