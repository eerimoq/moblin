import SwiftUI

private struct NumberView: View {
    @Binding var value: Int

    var body: some View {
        VStack {
            Text(String(value))
            Button {
                value += 1
            } label: {
                Text("+")
            }
            Button {
                if value > 0 {
                    value -= 1
                }
            } label: {
                Text("-")
            }
        }
    }
}

private struct NumberPairView: View {
    @Binding var title: String
    @Binding var numbers: [TextWidgetNumber]

    var body: some View {
        Text(title)
        HStack(spacing: 5) {
            ForEach($numbers) { number in
                NumberView(value: number.value)
            }
        }
    }
}

struct ControlView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingIsLiveConfirm: Bool = false
    @State private var pendingLiveValue = false
    @State private var isPresentingIsRecordingConfirm: Bool = false
    @State private var pendingRecordingValue = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Toggle(isOn: Binding(get: {
                    model.isLive
                }, set: { value in
                    pendingLiveValue = value
                    isPresentingIsLiveConfirm = true
                })) {
                    Text("Live")
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
                    Text("Recording")
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
                Toggle(isOn: Binding(get: {
                    model.isMuted
                }, set: { value in
                    model.setIsMuted(value: value)
                })) {
                    Text("Muted")
                }
                Button {
                    model.skipCurrentChatTextToSpeechMessage()
                } label: {
                    Text("Skip current TTS")
                }
                if false {
                    ForEach($model.numberPairs) { pair in
                        NumberPairView(title: pair.title, numbers: pair.numbers)
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
}
