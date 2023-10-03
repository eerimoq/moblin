import SwiftUI

struct ZoomLevelSettingsView: View {
    @ObservedObject var model: Model
    private var level: SettingsZoomLevel
    @State var value: String

    init(model: Model, level: SettingsZoomLevel) {
        self.model = model
        self.level = level
        value = String(level.level)
    }

    func submitName(name: String) {
        level.name = name
        model.store()
    }

    func submitLevel(level: String) {
        guard let level = Float(level) else {
            return
        }
        self.level.level = level
        model.store()
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: level.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: level.name)
            }
            NavigationLink(destination: TextEditView(
                title: "Level",
                value: String(level.level),
                onSubmit: submitLevel
            )) {
                TextItemView(name: "Level", value: String(level.level))
            }
        }.navigationTitle("Zoom level")
    }
}
