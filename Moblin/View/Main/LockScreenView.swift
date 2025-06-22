import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Text("")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.01))
            .onTapGesture(count: 2) { _ in
                model.toggleLockScreen()
            }
    }
}
