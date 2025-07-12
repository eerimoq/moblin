import SwiftUI

struct CreateButtonView: View {
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HCenter {
                Text("Create")
            }
        }
    }
}
