import SwiftUI

struct CreateButtonView: View {
    var action: () -> Void

    var body: some View {
        Button(action: action, label: {
            HStack(alignment: .center) {
                Text("Create")
            }
        })
    }
}

struct CreateButtonView_Previews: PreviewProvider {
    static var previews: some View {
        CreateButtonView(action: {})
    }
}
