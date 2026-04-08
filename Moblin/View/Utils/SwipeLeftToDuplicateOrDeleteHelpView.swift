import SwiftUI

struct SwipeLeftToDuplicateOrDeleteHelpView: View {
    let kind: String

    var body: some View {
        if isMac() {
            Text("Right-click on \(kind) to duplicate or delete it.")
        } else {
            Text("Swipe left on \(kind) to duplicate or delete it.")
        }
    }
}
