import SwiftUI

struct ContextMenuDuplicateButtonView: View {
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
    }
}
