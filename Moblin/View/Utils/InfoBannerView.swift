import SwiftUI

struct InfoBannerView: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            Text(message)
        }
    }
}
