import SwiftUI

struct StreamWizardCustomSrtSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return model.wizardCustomSrtUrl.isEmpty || model.wizardCustomSrtStreamId.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        model.wizardCustomSrtUrl = cleanUrl(url: model.wizardCustomSrtUrl)
        if model.wizardCustomSrtUrl.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: model.wizardCustomSrtUrl, allowedSchemes: ["srt", "srtla"]) ?? ""
        }
    }

    private func updateStreamId() {
        model.wizardCustomSrtStreamId = model.wizardCustomSrtStreamId.trim()
    }

    var body: some View {
        Form {
            Section {
                TextField("srt://107.32.12.132:5000", text: $model.wizardCustomSrtUrl)
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
                    "#!::r=stream/-NDZ1WPA4zjMBTJTyNwU,m=publish,...",
                    text: $model.wizardCustomSrtStreamId
                )
                .disableAutocorrection(true)
                .onSubmit {
                    updateStreamId()
                }
            } header: {
                Text("Stream id")
            }
            Section {
                NavigationLink(destination: StreamWizardSummarySettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardCustomProtocol = .srt
            model.wizardName = "Custom SRT"
        }
        .navigationTitle("SRT(LA)")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
