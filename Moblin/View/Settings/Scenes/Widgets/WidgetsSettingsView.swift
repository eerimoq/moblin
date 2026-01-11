import SwiftUI

private struct WidgetsSettingsItemView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        NavigationLink {
            WidgetSettingsView(model: model, database: database, widget: widget)
        } label: {
            Toggle(isOn: $widget.enabled) {
                HStack {
                    DraggableItemPrefixView()
                    IconAndTextView(
                        image: widget.image(),
                        text: widget.name,
                        longDivider: true
                    )
                    Spacer()
                }
            }
            .onChange(of: widget.enabled) { _ in
                model.sceneUpdated(attachCamera: model.isCaptureDeviceWidget(widget: widget))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            SwipeLeftToDeleteButtonView {
                database.widgets.removeAll(where: { $0 === widget })
                model.removeDeadWidgetsFromScenes()
                model.resetSelectedScene()
            }
        }
    }
}

struct WidgetsSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @State var presentingCreateWizard: Bool = false

    var body: some View {
        Section {
            ForEach(database.widgets) { widget in
                WidgetsSettingsItemView(database: database, widget: widget)
            }
            .onMove { froms, to in
                database.widgets.move(fromOffsets: froms, toOffset: to)
            }
            CreateButtonView {
                presentingCreateWizard = true
                model.createWidgetWizard.reset()
            }
            .sheet(isPresented: $presentingCreateWizard) {
                NavigationStack {
                    WidgetWizardSettingsView(model: model,
                                             database: database,
                                             createWidgetWizard: model.createWidgetWizard,
                                             presentingCreateWizard: $presentingCreateWizard)
                }
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
