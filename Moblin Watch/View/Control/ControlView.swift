import SwiftUI

struct ControlView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingIsLiveConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        VStack {
            Toggle(isOn: Binding(get: {
                model.isLive
            }, set: { value in
                pendingValue = value
                isPresentingIsLiveConfirm = true
            })) {
                Text("Is live")
            }
            .confirmationDialog("", isPresented: $isPresentingIsLiveConfirm) {
                Button(pendingValue ? String(localized: "Go Live") : String(localized: "End")) {
                    model.setIsLive(value: pendingValue)
                    isPresentingIsLiveConfirm = false
                }
                Button("Cancel") {
                    isPresentingIsLiveConfirm = false
                }
            }
            Spacer()
        }
    }
}
