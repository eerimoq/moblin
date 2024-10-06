import SwiftUI

struct StreamWizardCustomSrtSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return model.wizardCustomSrtUrl.isEmpty || model.wizardCustomSrtStreamId.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: model.wizardCustomSrtUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["srt", "srtla"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("srt://107.32.12.132:5000", text: $model.wizardCustomSrtUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: model.wizardCustomSrtUrl) { _ in
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
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            } header: {
                Text("Stream id")
            }
            Section {
                NavigationLink {
                    StreamWizardSummarySettingsView()
                } label: {
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
