import SwiftUI

struct SwipeLeftToDuplicateOrDeleteHelpView: View {
    let kind: String

    var body: some View {
        Text("Swipe left on \(kind) to duplicate or delete it.")
    }
}
