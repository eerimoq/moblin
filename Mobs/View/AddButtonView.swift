import SwiftUI

struct AddButtonView: View {
    var body: some View {
        Button(action: {
            print("Add")
        }, label: {
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
        AddButtonView()
    }
}
