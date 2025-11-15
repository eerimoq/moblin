import SwiftUI

private struct ControlLiveView: View {
    let model: Model
    @ObservedObject var control: Control
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            control.isLive
        }, set: { value in
            pendingValue = value
            isPresentingConfirm = true
        })) {
            Text("Live")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? "Go Live" : "End") {
                model.setIsLive(value: pendingValue)
            }
            Button("Cancel") {}
        }
    }
}

private struct ControlRecordingView: View {
    let model: Model
    @ObservedObject var control: Control
    @State private var isPresentingConfirm: Bool = false
    @State private var pendingValue = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            control.isRecording
        }, set: { value in
            pendingValue = value
            isPresentingConfirm = true
        })) {
            Text("Recording")
        }
        .confirmationDialog("", isPresented: $isPresentingConfirm) {
            Button(pendingValue ? "Start recording" : "Stop recording") {
                model.setIsRecording(value: pendingValue)
            }
            Button("Cancel") {}
        }
    }
}

private struct ControlMutedView: View {
    let model: Model
    @ObservedObject var control: Control

    var body: some View {
        Toggle(isOn: Binding(get: {
            control.isMuted
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

private struct ControlInstantReplayView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingSelect: Bool = false

    var body: some View {
        Button {
            isPresentingSelect = true
        } label: {
            Text("Instant replay")
        }
        .confirmationDialog("", isPresented: $isPresentingSelect) {
            ForEach([10, 15, 20], id: \.self) { duration in
                Button(String(localized: "\(duration) seconds")) {
                    model.instantReplay(duration: duration)
                }
            }
        }
    }
}

private struct ControlSaveReplayView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Button {
            model.saveReplay()
        } label: {
            Text("Save replay")
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

class Control: ObservableObject {
    @Published var isLive = false
    @Published var isRecording = false
    @Published var isMuted = false
}

struct ControlView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var preview: Preview

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ControlLiveView(model: model, control: model.control)
                ControlRecordingView(model: model, control: model.control)
                ControlMutedView(model: model, control: model.control)
                ControlInstantReplayView()
                ControlSaveReplayView()
                if !model.viaRemoteControl {
                    ControlSkipCurrentTtsView()
                    ControlCreateStreamMarkersView()
                }
                Spacer()
            }
            .padding()
        }
    }
}
