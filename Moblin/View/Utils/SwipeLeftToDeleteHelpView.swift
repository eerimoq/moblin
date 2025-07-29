import SwiftUI

struct SwipeLeftToDeleteHelpView: View {
    let kind: String

    var body: some View {
        Text("Swipe left on \(kind) to delete it.")
    }
}
