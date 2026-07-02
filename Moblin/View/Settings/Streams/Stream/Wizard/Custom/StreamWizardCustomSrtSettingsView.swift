import SwiftUI

struct StreamWizardSrtUrlSettingsView: View {
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @Binding var urlError: String

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.customSrtUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["srt", "srtla"]) ?? ""
        }
    }

    private func changePbkeylen(value: String) -> String? {
        guard !value.isEmpty else {
            return nil
        }
        guard let pbkeylen = Int(value) else {
            return String(localized: "Not a number")
        }
        guard [16, 24, 32].contains(pbkeylen) else {
            return String(localized: "Must be 16, 24 or 32")
        }
        return nil
    }

    var body: some View {
        Section {
            TextField(
                String("srt://107.32.12.132:5000?streamid=1234"),
                text: $createStreamWizard.customSrtUrl
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .onChange(of: createStreamWizard.customSrtUrl) { _ in
                updateUrlError()
                createStreamWizard.customSrtStreamId = extractSrtStreamId(
                    url: createStreamWizard.customSrtUrl
                ) ?? ""
                createStreamWizard.customSrtPassphrase = extractSrtPassphrase(
                    url: createStreamWizard.customSrtUrl
                ) ?? ""
                createStreamWizard.customSrtPbkeylen = extractSrtPbkeylen(
                    url: createStreamWizard.customSrtUrl
                ) ?? ""
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
        } footer: {
            Text("Replaces or adds the stream id to the URL.")
        }
        Section {
            TextField(
                String("Optional"),
                text: $createStreamWizard.customSrtPassphrase
            )
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
        } header: {
            Text("Passphrase (optional)")
        } footer: {
            Text("Replaces or adds the passphrase to the URL.")
        }
        Section {
            TextEditNavigationView(
                title: String(localized: "pbkeylen"),
                value: createStreamWizard.customSrtPbkeylen,
                onChange: changePbkeylen,
                onSubmit: { value in
                    createStreamWizard.customSrtPbkeylen = value
                },
                keyboardType: .numbersAndPunctuation,
                valueFormat: { value in
                    value.isEmpty ? String(localized: "Optional") : value
                }
            )
        } header: {
            Text("pbkeylen (optional)")
        } footer: {
            Text("Replaces or adds pbkeylen to the URL.")
        }
    }
}

struct StreamWizardCustomSrtSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        createStreamWizard.customSrtUrl.isEmpty
            || createStreamWizard.customSrtStreamId.isEmpty
            || !urlError.isEmpty
    }

    var body: some View {
        Form {
            StreamWizardSrtUrlSettingsView(createStreamWizard: createStreamWizard,
                                           urlError: $urlError)
            Section {
                NavigationLink {
                    StreamWizardGeneralSettingsView(model: model, createStreamWizard: createStreamWizard)
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
