import SwiftUI

struct AddButtonView: View {
    var action: () -> Void

    var body: some View {
        Button(action: action, label: {
            HStack(alignment: .center) {
                Text("Add")
            }
        })
    }
}

struct AddButtonView_Previews: PreviewProvider {
    static var previews: some View {
        AddButtonView(action: {})
    }
}
