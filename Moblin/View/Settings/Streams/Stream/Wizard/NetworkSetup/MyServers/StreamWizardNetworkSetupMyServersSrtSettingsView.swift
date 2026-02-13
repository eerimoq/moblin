import SwiftUI

struct StreamWizardNetworkSetupMyServersSrtSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.customSrtUrl.isEmpty || createStreamWizard.customSrtStreamId
            .isEmpty || !urlError
            .isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.customSrtUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["srt", "srtla"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(String("srt://107.32.12.132:5000"), text: $createStreamWizard.customSrtUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.customSrtUrl) { _ in
                        updateUrlError()
                    }
            } header: {
                Text("URL")
            } footer: {
                FormFieldError(error: urlError)
            }
            Section {
                TextField(
                    String("#!::r=stream/-NDZ1WPA4zjMBTJTyNwU,m=publish,..."),
                    text: $createStreamWizard.customSrtStreamId
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            } header: {
                Text("Stream id")
            }
            Section {
                NavigationLink {
                    StreamWizardObsRemoteControlSettingsView(
                        model: model,
                        createStreamWizard: createStreamWizard
                    )
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            createStreamWizard.customProtocol = .srt
        }
        .navigationTitle("SRT(LA)")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
