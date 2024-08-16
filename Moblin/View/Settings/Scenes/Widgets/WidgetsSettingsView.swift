import SwiftUI

struct WidgetsSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    var body: some View {
        Section {
            ForEach(database.widgets) { widget in
                NavigationLink(destination: WidgetSettingsView(
                    widget: widget,
                    type: widget.type.toString()
                )) {
                    Toggle(isOn: Binding(get: {
                        widget.enabled!
                    }, set: { value in
                        widget.enabled = value
                        model.sceneUpdated()
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
                model.store()
            })
            .onDelete(perform: { offsets in
                database.widgets.remove(atOffsets: offsets)
                model.removeDeadWidgetsFromScenes()
                model.store()
                model.resetSelectedScene()
            })
            CreateButtonView(action: {
                database.widgets.append(SettingsWidget(name: String(localized: "My widget")))
                model.fixAlertMedias()
                model.store()
            })
        } header: {
            Text("Widgets")
        } footer: {
            VStack(alignment: .leading) {
                Text("A widget can be used in zero or more scenes.")
                Text("")
                SwipeLeftToDeleteHelpView(kind: String(localized: "a widget"))
            }
        }
        Section {
            Button {
                model.reloadBrowserWidgets()
            } label: {
                HStack {
                    Spacer()
                    Text("Reload browser widgets")
                    Spacer()
                }
            }
        }
    }
}
