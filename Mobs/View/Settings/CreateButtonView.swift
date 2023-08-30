import SwiftUI

struct CreateButtonView: View {
    var action: () -> Void

    var body: some View {
        Button(action: action, label: {
            HStack {
                Spacer()
                Text("Create")
                Spacer()
            }
        })
    }
}

struct CreateButtonView_Previews: PreviewProvider {
    static var previews: some View {
        CreateButtonView(action: {})
    }
}
