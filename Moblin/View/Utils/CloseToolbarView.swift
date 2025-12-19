import SwiftUI

struct CloseToolbarButtonView: View {
    @Binding var presenting: Bool

    var body: some View {
        Button {
            presenting = false
        } label: {
            Image(systemName: "xmark")
        }
    }
}

struct CloseToolbar: ToolbarContent {
    @Binding var presenting: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            CloseToolbarButtonView(presenting: $presenting)
        }
    }
}
