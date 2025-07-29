import SwiftUI

struct SwipeLeftToRemoveHelpView: View {
    let kind: String

    var body: some View {
        Text("Swipe left on \(kind) to remove it.")
    }
}
