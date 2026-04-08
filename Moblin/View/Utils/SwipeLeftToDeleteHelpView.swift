import SwiftUI

struct SwipeLeftToDeleteHelpView: View {
    let kind: String

    var body: some View {
        if isMac() {
            Text("Right-click or swipe left on \(kind) to delete it.")
        } else {
            Text("Swipe left on \(kind) to delete it.")
        }
    }
}
