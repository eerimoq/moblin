import SwiftUI

struct ControlView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingIsLiveConfirm: Bool = false
    @State private var isPresentingIsRecordingConfirm: Bool = false
    @State private var pendingLiveValue = false
    @State private var pendingRecordingValue = false

    var body: some View {
        VStack {
            Toggle(isOn: Binding(get: {
                model.isLive
            }, set: { value in
                pendingLiveValue = value
                isPresentingIsLiveConfirm = true
            })) {
                Text("Is live")
            }
            .confirmationDialog("", isPresented: $isPresentingIsLiveConfirm) {
                Button(pendingLiveValue ? String(localized: "Go Live") : String(localized: "End")) {
                    model.setIsLive(value: pendingLiveValue)
                    isPresentingIsLiveConfirm = false
                }
                Button("Cancel") {
                    isPresentingIsLiveConfirm = false
                }
            }
            Toggle(isOn: Binding(get: {
                model.isRecording
            }, set: { value in
                pendingRecordingValue = value
                isPresentingIsRecordingConfirm = true
            })) {
                Text("Is recording")
            }
            .confirmationDialog("", isPresented: $isPresentingIsRecordingConfirm) {
                Button(pendingRecordingValue ? String(localized: "Start") : String(localized: "Stop")) {
                    model.setIsRecording(value: pendingRecordingValue)
                    isPresentingIsRecordingConfirm = false
                }
                Button("Cancel") {
                    isPresentingIsRecordingConfirm = false
                }
            }
            Spacer()
        }
    }
}
