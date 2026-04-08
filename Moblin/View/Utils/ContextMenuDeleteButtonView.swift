import SwiftUI

struct ContextMenuDeleteButtonView: View {
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

extension View {
    func contextMenuDeleteButton(disabled: Bool = false, action: @escaping () -> Void) -> some View {
        contextMenu {
            if !disabled, isMac() {
                ContextMenuDeleteButtonView(action: action)
            }
        }
    }
}
