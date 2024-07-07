import SwiftUI

struct WidgetMapSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        guard width > 0, width < 4000 else {
            return
        }
        widget.map!.width = width
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        guard height > 0, height < 4000 else {
            return
        }
        widget.map!.height = height
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Section {
            TextEditNavigationView(
                title: String(localized: "Width"),
                value: String(widget.map!.width),
                onSubmit: submitWidth,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(title: String(localized: "Height"),
                                   value: String(widget.map!.height),
                                   onSubmit: submitHeight,
                                   keyboardType: .numbersAndPunctuation)
        }
    }
}
