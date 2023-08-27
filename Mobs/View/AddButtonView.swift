import SwiftUI

struct AddButtonView: View {
    var action: () -> Void

    var body: some View {
        Button(action: self.action, label: {
            HStack {
                Spacer()
                Text("Add")
                Spacer()
            }
        })
    }
}

struct AddButtonView_Previews: PreviewProvider {
    static var previews: some View {
        AddButtonView(action: {})
    }
}
