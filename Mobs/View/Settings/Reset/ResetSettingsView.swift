import SwiftUI

struct ResetSettingsView: View {
    @ObservedObject var model: Model
    @State private var isPresentingResetConfirm: Bool = false

    var body: some View {
        HStack {
            Spacer()
            Button("Reset settings", role: .destructive) {
                isPresentingResetConfirm = true
            }
            .confirmationDialog("Are you sure?", isPresented: $isPresentingResetConfirm) {
                Button("Reset settings", role: .destructive) {
                    model.settings.reset()
                    model.reloadStream()
                    model.resetSelectedScene()
                 }
            }
            Spacer()
        }
    }
}
