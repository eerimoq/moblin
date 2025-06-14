import SwiftUI

private struct StreamButtonText: View {
    @EnvironmentObject var model: Model
    var text: String

    var body: some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundColor(.white)
            .frame(minWidth: 60)
            .padding(5)
            .background(model.database.streamButtonColor.color())
            .cornerRadius(10)
    }
}

struct StreamButton: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingGoLiveConfirm = false
    @State private var isPresentingGoLiveNotificationConfirm = false
    @State private var isPresentingStopConfirm = false

    var body: some View {
        if model.isLive {
            Button {
                isPresentingStopConfirm = true
            } label: {
                StreamButtonText(text: String(localized: "End"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white)
                    )
            }
            .confirmationDialog("", isPresented: $isPresentingGoLiveNotificationConfirm) {
                Button("Send Go live notification") {
                    model.sendGoLiveNotification()
                }
            }
            .confirmationDialog("", isPresented: $isPresentingStopConfirm) {
                if model.stream.obsAutoStopStream && model.stream.obsAutoStopRecording {
                    Button("End but leave OBS streaming and recording") {
                        model.stopStream(stopObsStreamIfEnabled: false, stopObsRecordingIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopStream {
                    Button("End but leave OBS streaming") {
                        model.stopStream(stopObsStreamIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopRecording {
                    Button("End but leave OBS recording") {
                        model.stopStream(stopObsRecordingIfEnabled: false)
                    }
                }
                Button("End") {
                    model.stopStream()
                }
            }
        } else if model.isStreamConfigured() {
            Button {
                isPresentingGoLiveConfirm = true
            } label: {
                StreamButtonText(text: String(localized: "Go Live"))
            }
            .confirmationDialog("", isPresented: $isPresentingGoLiveConfirm) {
                Button("Go Live") {
                    model.startStream()
                    if model.isGoLiveNotificationConfigured() {
                        isPresentingGoLiveNotificationConfirm = true
                    }
                }
            }
        } else {
            Button {
                model.resetWizard()
                model.isPresentingSetupWizard = true
            } label: {
                StreamButtonText(text: String(localized: "Setup"))
            }
            .sheet(isPresented: $model.isPresentingSetupWizard) {
                NavigationStack {
                    StreamWizardSettingsView()
                }
            }
        }
    }
}
