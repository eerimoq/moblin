import SwiftUI

struct AddButtonView: View {
    let action: () -> Void

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
