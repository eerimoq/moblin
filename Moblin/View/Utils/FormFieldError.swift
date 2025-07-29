import SwiftUI

struct FormFieldError: View {
    let error: String

    var body: some View {
        if error != "" {
            Text(error)
                .foregroundColor(.red)
                .bold()
                .font(.callout)
            Text("")
        }
    }
}
