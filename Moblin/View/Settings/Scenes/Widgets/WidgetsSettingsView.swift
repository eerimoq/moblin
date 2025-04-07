import SwiftUI

struct WidgetsSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Section {
            ForEach(database.widgets) { widget in
                NavigationLink {
                    WidgetSettingsView(
                        widget: widget,
                        type: widget.type.toString(),
                        name: widget.name
                    )
                } label: {
                    Toggle(isOn: Binding(get: {
                        widget.enabled!
                    }, set: { value in
                        widget.enabled = value
                        model.sceneUpdated(attachCamera: model.isCaptureDeviceVideoSoureWidget(widget: widget))
                    })) {
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
                }
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
                model.objectWillChange.send()
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
