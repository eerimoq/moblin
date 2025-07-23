import SwiftUI

struct ResetSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingResetConfirm: Bool = false

    var body: some View {
        HCenter {
            Button("Reset settings", role: .destructive) {
                isPresentingResetConfirm = true
            }
            .confirmationDialog("Are you sure?", isPresented: $isPresentingResetConfirm) {
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
