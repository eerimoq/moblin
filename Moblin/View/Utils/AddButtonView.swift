import SwiftUI

struct AddButtonView: View {
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HCenter {
                Text("Add")
            }
        }
    }
}
