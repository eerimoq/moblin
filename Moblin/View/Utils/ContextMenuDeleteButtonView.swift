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
    func contextMenuDeleteButton(enabled: Bool = true, action: @escaping () -> Void) -> some View {
        contextMenu {
            if enabled {
                ContextMenuDeleteButtonView(action: action)
            }
        }
    }
}
