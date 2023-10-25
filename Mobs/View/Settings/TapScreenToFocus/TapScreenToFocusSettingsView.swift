import SwiftUI

struct TapScreenToFocusSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Toggle("Tap screen to focus", isOn: Binding(get: {
            model.database.tapToFocus
        }, set: { value in
            model.database.tapToFocus = value
            model.store()
            if !value {
                model.setAutoFocus()
            }
        }))
    }
}
