import SwiftUI

struct TapScreenToFocusSettingsView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        Toggle("Tap screen to focus", isOn: $database.tapToFocus)
            .onChange(of: database.tapToFocus) { value in
                if !value {
                    model.setAutoFocus()
                }
            }
    }
}
