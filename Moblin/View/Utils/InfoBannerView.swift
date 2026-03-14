import SwiftUI

struct InfoBannerView: View {
    let text: LocalizedStringKey

    var body: some View {
        Section {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text(text)
            }
        }
    }
}
