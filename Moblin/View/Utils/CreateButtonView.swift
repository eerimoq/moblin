import SwiftUI

struct CreateButtonView: View {
    let action: () -> Void

    var body: some View {
        TextButtonView("Create") {
            action()
        }
    }
}
