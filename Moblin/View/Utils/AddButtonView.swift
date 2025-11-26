import SwiftUI

struct AddButtonView: View {
    let action: () -> Void

    var body: some View {
        TextButtonView("Add") {
            action()
        }
    }
}
