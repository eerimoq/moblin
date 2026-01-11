import SwiftUI

struct SwipeLeftToDeleteButtonView: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }
}
