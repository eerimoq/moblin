import SwiftUI

private struct StreamButtonText: View {
    @ObservedObject var database: Database
    let text: String

    var body: some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .frame(minWidth: 60)
            .padding(5)
            .background(database.streamButtonColorColor)
            .cornerRadius(10)
    }
}

private struct EndButtonView: View {
    @EnvironmentObject var model: Model
    @Binding var presentingGoLiveNotificationConfirm: Bool
    @State private var presentingStopConfirm = false

    var body: some View {
        StreamButtonText(database: model.database, text: String(localized: "End"))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white)
            )
            .onTapGesture {
                presentingStopConfirm = true
            }
            .onLongPressGesture {
                model.toggleShowingPanel(type: nil, panel: .streamingButtonSettings)
            }
            .confirmationDialog("", isPresented: $presentingGoLiveNotificationConfirm) {
                Button("Send Go live notification") {
                    model.sendGoLiveNotification()
                }
            }
            .confirmationDialog("", isPresented: $presentingStopConfirm) {
                if model.stream.obsAutoStopStream && model.stream.obsAutoStopRecording {
                    Button("End but leave OBS streaming and recording") {
                        _ = model.stopStream(stopObsStreamIfEnabled: false, stopObsRecordingIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopStream {
                    Button("End but leave OBS streaming") {
                        _ = model.stopStream(stopObsStreamIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopRecording {
                    Button("End but leave OBS recording") {
                        _ = model.stopStream(stopObsRecordingIfEnabled: false)
                    }
                }
                Button("End") {
                    _ = model.stopStream()
                }
            }
    }
}

private struct GoLiveButtonView: View {
    @EnvironmentObject var model: Model
    @Binding var presentingGoLiveNotificationConfirm: Bool
    @State private var presentingGoLiveConfirm = false

    var body: some View {
        StreamButtonText(database: model.database, text: String(localized: "Go Live"))
            .onTapGesture {
                presentingGoLiveConfirm = true
            }
            .onLongPressGesture {
                model.toggleShowingPanel(type: nil, panel: .streamingButtonSettings)
            }
            .confirmationDialog("", isPresented: $presentingGoLiveConfirm) {
                Button("Go Live") {
                    model.startStream()
                    if model.isGoLiveNotificationConfigured() {
                        presentingGoLiveNotificationConfirm = true
                    }
                }
            } message: {
                Text("You are about to go live to '\(model.stream.name)'!")
            }
    }
}

private struct SetupButtonView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        StreamButtonText(database: model.database, text: String(localized: "Setup"))
            .onTapGesture {
                model.resetWizard()
                createStreamWizard.presentingSetup = true
            }
            .onLongPressGesture {
                model.toggleShowingPanel(type: nil, panel: .streamingButtonSettings)
            }
            .sheet(isPresented: $createStreamWizard.presentingSetup) {
                NavigationStack {
                    StreamWizardSettingsView(model: model, createStreamWizard: createStreamWizard)
                }
            }
    }
}

struct StreamButton: View {
    @EnvironmentObject var model: Model
    @State private var presentingGoLiveNotificationConfirm = false

    var body: some View {
        if model.isLive {
            EndButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
        } else if model.isStreamConfigured() {
            GoLiveButtonView(presentingGoLiveNotificationConfirm: $presentingGoLiveNotificationConfirm)
        } else {
            SetupButtonView(createStreamWizard: model.createStreamWizard)
        }
    }
}
