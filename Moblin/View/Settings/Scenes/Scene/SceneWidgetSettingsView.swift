import SwiftUI

struct SceneWidgetSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneWidget: SettingsSceneWidget
    let widget: SettingsWidget

    var body: some View {
        Form {
            WidgetLayoutView(model: model,
                             database: database,
                             layout: $sceneWidget.layout,
                             widget: widget,
                             numericInput: $database.sceneNumericInput)
            ShortcutSectionView {
                WidgetShortcutView(model: model, database: model.database, widget: widget)
                if widget.type == .scene,
                   let scene = model.database.findScene(id: widget.scene.sceneId)
                {
                    SceneShortcutView(database: model.database, scene: scene)
                }
            }
        }
        .navigationTitle(widget.name)
    }
}
