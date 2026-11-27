import SwiftUI

struct SceneWidgetSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneWidget: SettingsSceneWidget
    @ObservedObject var widget: SettingsWidget
    let size: CGSize

    var body: some View {
        Form {
            WidgetLayoutView(model: model, sceneWidget: sceneWidget, widget: widget, size: size)
            WidgetSettingsSectionsView(model: model, database: database, widget: widget)
        }
        .navigationTitle(widget.name)
    }
}
