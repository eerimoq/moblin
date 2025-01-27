import SwiftUI

struct StreamButtonText: View {
    @EnvironmentObject var model: Model
    var text: String

    var body: some View {
        Text(text)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundColor(.white)
            .frame(minWidth: 60)
            .padding(5)
            .background(model.database.streamButtonColor!.color())
            .cornerRadius(10)
    }
}

struct StreamButton: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingGoLiveConfirm: Bool = false
    @State private var isPresentingStopConfirm: Bool = false

    var body: some View {
        if model.isLive {
            Button(action: {
                isPresentingStopConfirm = true
            }, label: {
                StreamButtonText(text: String(localized: "End"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white)
                    )
            })
            .confirmationDialog("", isPresented: $isPresentingStopConfirm) {
                if model.stream.obsAutoStopStream! && model.stream.obsAutoStopRecording! {
                    Button("End but leave OBS streaming and recording") {
                        model.stopStream(stopObsStreamIfEnabled: false, stopObsRecordingIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopStream! {
                    Button("End but leave OBS streaming") {
                        model.stopStream(stopObsStreamIfEnabled: false)
                    }
                } else if model.stream.obsAutoStopRecording! {
                    Button("End but leave OBS recording") {
                        model.stopStream(stopObsRecordingIfEnabled: false)
                    }
                }
                Button("End") {
                    model.stopStream()
                }
            }
        } else if model.isStreamConfigured() {
            Button(action: {
                isPresentingGoLiveConfirm = true
            }, label: {
                StreamButtonText(text: String(localized: "Go Live"))
            })
            .confirmationDialog("", isPresented: $isPresentingGoLiveConfirm) {
                Button("Go Live") {
                    model.startStream()
                }
            }
        } else {
            Button(action: {
                model.resetWizard()
                model.isPresentingSetupWizard = true
            }, label: {
                StreamButtonText(text: String(localized: "Setup"))
            })
            .sheet(isPresented: $model.isPresentingSetupWizard) {
                NavigationStack {
                    StreamWizardSettingsView()
                }
            }
        }
    }
}
