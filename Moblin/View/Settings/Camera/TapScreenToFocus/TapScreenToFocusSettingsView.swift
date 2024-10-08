import SwiftUI

struct TapScreenToFocusSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Toggle("Tap screen to focus", isOn: Binding(get: {
            model.database.tapToFocus
        }, set: { value in
            model.database.tapToFocus = value
            if !value {
                model.setAutoFocus()
            }
        }))
    }
}
