import SwiftUI

struct AddButtonView: View {
    var action: () -> Void

    var body: some View {
        Button(action: action, label: {
            HStack {
                Spacer()
                Text("Add")
                Spacer()
            }
        })
    }
}
