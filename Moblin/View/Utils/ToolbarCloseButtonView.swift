import SwiftUI

struct ToolbarCloseButtonView: View {
    @Binding var presenting: Bool

    var body: some View {
        Button {
            presenting = false
        } label: {
            Image(systemName: "xmark")
        }
    }
}
