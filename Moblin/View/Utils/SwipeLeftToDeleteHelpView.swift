import SwiftUI

struct SwipeLeftToDeleteHelpView: View {
    let kind: String

    var body: some View {
        if isMac() {
            Text("Right-click on \(kind) to delete it.")
        } else {
            Text("Swipe left on \(kind) to delete it.")
        }
    }
}
