import SwiftUI

struct BorderlessButtonView: View {
    let text: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(text)
        }
        .buttonStyle(.borderless)
    }
}
