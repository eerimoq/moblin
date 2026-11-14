import SwiftUI

struct SceneWidgetSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneWidget: SettingsSceneWidget
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        Form {
            WidgetLayoutView(model: model,
                             database: database,
                             layout: $sceneWidget.layout,
                             widget: widget,
                             numericInput: $database.sceneNumericInput)
            WidgetSettingsSectionsView(model: model, database: database, widget: widget)
        }
        .navigationTitle(widget.name)
    }
}
