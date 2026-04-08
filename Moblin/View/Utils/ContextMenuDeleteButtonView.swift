import SwiftUI

struct ContextMenuDeleteButtonView: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive) {
            action()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
