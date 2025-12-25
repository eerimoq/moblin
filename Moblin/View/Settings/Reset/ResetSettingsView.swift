import SwiftUI

struct ResetSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var presentingResetConfirm: Bool = false

    var body: some View {
        HCenter {
            Button("Reset settings", role: .destructive) {
                presentingResetConfirm = true
            }
            .confirmationDialog("Are you sure?", isPresented: $presentingResetConfirm) {
                Button("Reset settings", role: .destructive) {
                    model.settings.reset()
                    model.setCurrentStream()
                    model.reloadStream()
                    model.resetSelectedScene()
                    model.updateQuickButtonStates()
                }
            }
        }
    }
}
