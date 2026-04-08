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

extension View {
    func contextMenuDeleteButton(disabled: Bool = false, action: @escaping () -> Void) -> some View {
        contextMenu {
            if !disabled {
                ContextMenuDeleteButtonView(action: action)
            }
        }
    }
}
