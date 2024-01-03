import SwiftUI

struct StreamWizardCustonRtmpSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return model.wizardCustomRtmpUrl.isEmpty || model.wizardCustomRtmpStreamKey.isEmpty || !urlError
            .isEmpty
    }

    private func updateUrlError() {
        model.wizardCustomRtmpUrl = cleanUrl(url: model.wizardCustomRtmpUrl)
        if model.wizardCustomRtmpUrl.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: model.wizardCustomRtmpUrl, allowedSchemes: ["rtmp", "rtmps"]) ?? ""
        }
    }

    private func updateStreamKey() {
        model.wizardCustomRtmpStreamKey = model.wizardCustomRtmpStreamKey.trim()
    }

    var body: some View {
        Form {
            Section {
                TextField("rtmp://arn03.contribute.live-video.net/app/", text: $model.wizardCustomRtmpUrl)
                    .disableAutocorrection(true)
                    .onSubmit {
                        updateUrlError()
                    }
            } header: {
                Text("Url")
            } footer: {
                FormFieldError(error: urlError)
            }
            Section {
                TextField(
                    "live_48950233_okF4f455GRWEF443fFr23GRbt5rEv",
                    text: $model.wizardCustomRtmpStreamKey
                )
                .disableAutocorrection(true)
                .onSubmit {
                    updateStreamKey()
                }
            } header: {
                Text("Stream key")
            }
            Section {
                NavigationLink(destination: StreamWizardSummarySettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardCustomProtocol = .rtmp
            model.wizardName = "Custom RTMP"
        }
        .navigationTitle("RTMP(S)")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
