import SwiftUI

struct StreamWizardCustomRtmpSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return model.wizardCustomRtmpUrl.isEmpty || model.wizardCustomRtmpStreamKey.isEmpty || !urlError
            .isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: model.wizardCustomRtmpUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(
                url: url,
                allowedSchemes: ["rtmp", "rtmps"],
                rtmpStreamKeyRequired: false
            ) ??
                ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("rtmp://arn03.contribute.live-video.net/app/", text: $model.wizardCustomRtmpUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: model.wizardCustomRtmpUrl) { _ in
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
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
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
