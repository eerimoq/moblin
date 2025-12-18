import SwiftUI

struct SwipeLeftToDeleteButtonView: View {
    @Binding var presentingConfirmation: Bool

    var body: some View {
        Button {
            presentingConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }
}
