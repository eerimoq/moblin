import SwiftUI

struct CreateButtonView: View {
    var body: some View {
        Button(action: {
            print("Create")
        }, label: {
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
        CreateButtonView()
    }
}
