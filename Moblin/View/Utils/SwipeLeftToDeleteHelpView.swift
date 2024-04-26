import SwiftUI

struct SwipeLeftToDeleteHelpView: View {
    var kind: String

    var body: some View {
        Text("Swipe left on \(kind) to delete it.")
    }
}
