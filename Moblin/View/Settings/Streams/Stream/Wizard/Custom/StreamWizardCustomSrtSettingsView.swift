import SwiftUI

struct StreamWizardCustomSrtSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.customSrtUrl.isEmpty || createStreamWizard.customSrtStreamId.isEmpty || !urlError
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
                TextField("srt://107.32.12.132:5000", text: $createStreamWizard.customSrtUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.customSrtUrl) { _ in
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
                    text: $createStreamWizard.customSrtStreamId
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            } header: {
                Text("Stream id")
            }
            Section {
                NavigationLink {
                    StreamWizardSummarySettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            createStreamWizard.customProtocol = .srt
            createStreamWizard.name = makeUniqueName(name: String(localized: "Custom SRT"),
                                                     existingNames: model.database.streams)
        }
        .navigationTitle("SRT(LA)")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
