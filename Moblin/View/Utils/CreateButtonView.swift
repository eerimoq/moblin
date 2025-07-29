import SwiftUI

struct CreateButtonView: View {
    let action: () -> Void

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
