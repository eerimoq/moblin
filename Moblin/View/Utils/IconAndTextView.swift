import SwiftUI

struct IconAndTextView: View {
    let image: String
    let text: String
    var longDivider: Bool = false

    var body: some View {
        HStack {
            if longDivider {
                Text("")
            }
            Image(systemName: image)
                .frame(width: iconWidth)
            Text(text)
        }
    }
}

struct IconAndTextSettingView: View {
    let image: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 0) {
            Text("")
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: image)
                Spacer(minLength: 0)
            }
            .frame(width: 25)
            Text(text)
                .padding([.leading], 3)
        }
    }
}
