import AVFoundation
import SwiftUI

private struct ObsStartStopButtonView: View {
    @Binding var state: ObsOutputState
    let startAction: () -> Void
    let stopAction: () -> Void
    let startText: LocalizedStringKey
    let stopText: LocalizedStringKey
    @State private var isPresentingStartConfirm = false
    @State private var isPresentingStopConfirm = false

    var body: some View {
        switch state {
        case .stopped:
            Section {
                TextButtonView(startText) {
                    isPresentingStartConfirm = true
                }
                .confirmationDialog("", isPresented: $isPresentingStartConfirm) {
                    Button(startText) {
                        startAction()
                    }
                }
            }
        case .starting:
            Section {
                HCenter {
                    Text("Starting...")
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(Color.gray)
        case .started:
            Section {
                TextButtonView(stopText) {
                    isPresentingStopConfirm = true
                }
                .confirmationDialog("", isPresented: $isPresentingStopConfirm) {
                    Button(stopText) {
                        stopAction()
                    }
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(Color.blue)
        case .stopping:
            Section {
                HCenter {
                    Text("Stopping...")
                }
            }
            .foregroundStyle(.white)
            .listRowBackground(Color.gray)
        }
    }
}

private struct ObsStartStopStreamingView: View {
    let model: Model
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        ObsStartStopButtonView(state: $obsQuickButton.streamingState,
                               startAction: {
                                   model.obsStartStream()
                               }, stopAction: {
                                   model.obsStopStream()
                               }, startText: "Start streaming",
                               stopText: "Stop streaming")
    }
}

private struct ObsStartStopRecordingView: View {
    let model: Model
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        ObsStartStopButtonView(state: $obsQuickButton.recordingState,
                               startAction: {
                                   model.obsStartRecording()
                               }, stopAction: {
                                   model.obsStopRecording()
                               }, startText: "Start recording",
                               stopText: "Stop recording")
    }
}

private struct ObsSettingsView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream

    var body: some View {
        Form {
            Toggle("Enabled", isOn: $stream.obsWebSocketEnabled)
                .onChange(of: stream.obsWebSocketEnabled) { _ in
                    if stream.enabled {
                        model.obsWebSocketEnabledUpdated()
                    }
                }
            StreamObsRemoteControlSettingsInnerView(stream: stream)
        }
        .navigationTitle("OBS remote control")
    }
}

private struct ObsSnapshotView: View {
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        Section {
            if let image = obsQuickButton.screenshot {
                Image(image, scale: 1, label: Text(""))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(.black)
            } else {
                Text("No snapshot received yet.")
            }
        } header: {
            Text("Current scene snapshot")
        }
    }
}

private struct ObsScenesView: View {
    let model: Model
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        Section {
            Picker("", selection: $obsQuickButton.currentScenePicker) {
                ForEach(obsQuickButton.scenes, id: \.self) { scene in
                    Text(scene)
                }
            }
            .onChange(of: obsQuickButton.currentScenePicker) { _ in
                guard obsQuickButton.currentScene != obsQuickButton.currentScenePicker else {
                    return
                }
                model.setObsScene(name: obsQuickButton.currentScenePicker)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Scenes")
        }
    }
}

private struct ObsSceneAudioInputsView: View {
    let model: Model
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        Section {
            ForEach(obsQuickButton.sceneInputs) { input in
                if let muted = input.muted {
                    HStack {
                        Text(input.name)
                        Spacer()
                        Button {
                            model.obsMuteAudio(inputName: input.name, muted: !muted)
                        } label: {
                            if muted {
                                Image(systemName: "microphone.slash")
                                    .foregroundStyle(.red)
                            } else {
                                Image(systemName: "microphone")
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Scene audio inputs")
        }
    }
}

private struct ObsFixSourceView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        if !obsQuickButton.fixOngoing {
            Section {
                TextButtonView("Fix \(stream.obsSourceName) source") {
                    model.obsFixStream()
                }
            } footer: {
                Text("""
                Restarts the \(stream.obsSourceName) source to hopefully fix \
                audio and video issues.
                """)
            }
        } else {
            Section {
                HCenter {
                    Text("Fixing...")
                }
                .foregroundStyle(.white)
            } footer: {
                Text("""
                Restarts the \(stream.obsSourceName) source to hopefully fix \
                audio and video issues.
                """)
            }
            .listRowBackground(Color.gray)
        }
    }
}

private struct ObsAudioSyncView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var obsQuickButton: QuickButtonObs

    private func submitAudioDelay(value: String) -> String {
        let offsetDouble = Double(value) ?? 0
        var offset = Int(offsetDouble)
        offset = offset.clamped(to: obsMinimumAudioDelay ... obsMaximumAudioDelay)
        model.setObsAudioDelay(offset: offset)
        return String(offset)
    }

    var body: some View {
        Section {
            ValueEditView(
                title: "Delay",
                number: Float(obsQuickButton.audioDelay),
                value: "\(obsQuickButton.audioDelay)",
                minimum: Float(obsMinimumAudioDelay),
                maximum: Float(min(obsMaximumAudioDelay, 9999)),
                onSubmit: submitAudioDelay,
                increment: 10,
                unit: "ms"
            )
        } header: {
            Text("\(stream.obsSourceName) source audio sync")
        }
    }
}

private struct ObsAudioLevelsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        Section {
            if model.isLive {
                if !obsQuickButton.audioVolume.isEmpty {
                    Text(obsQuickButton.audioVolume)
                } else {
                    Text("No audio levels received yet.")
                }
            } else {
                Text("Go live to see audio levels.")
            }
        } header: {
            Text("\(stream.obsSourceName) source audio levels")
        }
    }
}

private struct ObsConnectedView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        ObsStartStopStreamingView(model: model, obsQuickButton: obsQuickButton)
        ObsStartStopRecordingView(model: model, obsQuickButton: obsQuickButton)
        ObsSnapshotView(obsQuickButton: obsQuickButton)
        ObsScenesView(model: model, obsQuickButton: obsQuickButton)
        ObsSceneAudioInputsView(model: model, obsQuickButton: obsQuickButton)
        if !stream.obsSourceName.isEmpty {
            ObsFixSourceView(model: model, stream: stream, obsQuickButton: obsQuickButton)
            ObsAudioSyncView(model: model, stream: stream, obsQuickButton: obsQuickButton)
            ObsAudioLevelsView(stream: stream, obsQuickButton: obsQuickButton)
        } else {
            Text("""
            Configure source name in \
            Settings → Streams → \(stream.name) → OBS remote control for \
            Fix button and more.
            """)
        }
    }
}

struct QuickButtonObsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var obsQuickButton: QuickButtonObs

    var body: some View {
        Form {
            if !model.isObsRemoteControlConfigured() {
            } else if !model.isObsConnected() {
                Section {
                    Text("Unable to connect the OBS server. Retrying every 5 seconds.")
                }
            } else {
                ObsConnectedView(stream: stream, obsQuickButton: obsQuickButton)
            }
            if stream !== fallbackStream {
                Section {
                    NavigationLink {
                        ObsSettingsView(model: model, stream: stream)
                    } label: {
                        Label("OBS remote control", systemImage: "dot.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
        }
        .onAppear {
            model.listObsScenes(updateAudioInputs: true)
            obsQuickButton.startObsSourceScreenshot()
            model.startObsAudioVolume()
            model.updateObsAudioDelay()
        }
        .onDisappear {
            obsQuickButton.stopObsSourceScreenshot()
            model.stopObsAudioVolume()
        }
        .navigationTitle("OBS remote control")
    }
}
