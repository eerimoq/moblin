import SwiftUI

private struct ControlLiveView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.isLive
        }, set: { value in
            pendingValue = value
            isPresentingConfirm = true
        })) {
            Text("Live")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? String(localized: "Go Live") : String(localized: "End")) {
                model.setIsLive(value: pendingValue)
            }
            Button("Cancel") {}
        }
    }
}

private struct ControlRecordingView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.isRecording
        }, set: { value in
            pendingValue = value
            isPresentingConfirm = true
        })) {
            Text("Recording")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? String(localized: "Start") : String(localized: "Stop")) {
                model.setIsRecording(value: pendingValue)
            }
            Button("Cancel") {}
        }
    }
}

private struct ControlMutedView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Toggle(isOn: Binding(get: {
            model.isMuted
        }, set: { value in
            model.setIsMuted(value: value)
        })) {
            Text("Muted")
        }
    }
}

private struct ControlSkipCurrentTtsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.skipCurrentChatTextToSpeechMessage()
        } label: {
            Text("Skip current TTS")
        }
    }
}

private struct ControlCreateStreamMarkersView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.createStreamMarker()
        } label: {
            Text("Create stream marker")
        }
    }
}

struct ControlView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ControlLiveView()
                ControlRecordingView()
                ControlMutedView()
                ControlSkipCurrentTtsView()
                ControlCreateStreamMarkersView()
                Spacer()
            }
            .padding()
        }
    }
}
