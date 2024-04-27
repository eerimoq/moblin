import SwiftUI

struct WidgetsSettingsView: View {
    @EnvironmentObject var model: Model

    var database: Database {
        model.database
    }

    func isWidgetUsed(widget: SettingsWidget) -> Bool {
        for scene in database.scenes {
            for sceneWidget in scene.widgets where sceneWidget.widgetId == widget.id {
                return true
            }
        }
        return false
    }

    var body: some View {
        Form {
            Text("A list of all widgets. A widget can be used in zero or more scenes.")
            Section {
                Button {
                    model.reloadBrowserWidgets()
                } label: {
                    HStack {
                        Spacer()
                        Text("Reload browsers")
                        Spacer()
                    }
                }
            }
            Section {
                ForEach(database.widgets) { widget in
                    NavigationLink(destination: WidgetSettingsView(
                        widget: widget
                    )) {
                        HStack {
                            DraggableItemPrefixView()
                            IconAndTextView(
                                image: widgetImage(widget: widget),
                                text: widget.name,
                                longDivider: true
                            )
                            Spacer()
                            if !isWidgetUsed(widget: widget) {
                                Text("Unused")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .deleteDisabled(isWidgetUsed(widget: widget))
                }
                .onMove(perform: { froms, to in
                    database.widgets.move(fromOffsets: froms, toOffset: to)
                    model.store()
                })
                .onDelete(perform: { offsets in
                    database.widgets.remove(atOffsets: offsets)
                    model.store()
                    model.resetSelectedScene()
                })
                CreateButtonView(action: {
                    database.widgets.append(SettingsWidget(name: String(localized: "My widget")))
                    model.store()
                    model.resetSelectedScene()
                })
            } footer: {
                VStack(alignment: .leading) {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a widget"))
                    Text("")
                    Text("Only unused widgets can be deleted.")
                }
            }
        }
        .navigationTitle("Widgets")
        .toolbar {
            SettingsToolbar()
        }
    }
}
