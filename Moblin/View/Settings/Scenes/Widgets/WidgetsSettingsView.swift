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
        for button in database.buttons {
            if button.type == .widget && button.widget.widgetId == widget.id {
                return true
            }
        }
        return false
    }

    var body: some View {
        Form {
            Section {
                ForEach(database.widgets) { widget in
                    NavigationLink(destination: WidgetSettingsView(
                        widget: widget
                    )) {
                        HStack {
                            DraggableItemPrefixView()
                            IconAndTextView(
                                image: widgetImage(widget: widget),
                                text: widget.name
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
                    database.widgets.append(SettingsWidget(name: "My widget"))
                    model.store()
                    model.resetSelectedScene()
                })
            } footer: {
                Text("Only unused widgets can be deleted.")
            }
        }
        .navigationTitle("Widgets")
        .toolbar {
            SettingsToolbar()
        }
    }
}
