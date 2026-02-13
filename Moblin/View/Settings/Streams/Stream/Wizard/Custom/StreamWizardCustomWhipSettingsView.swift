import SwiftUI

struct StreamWizardCustomWhipSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.customWhipUrl.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.customWhipUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["whip", "whips"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(String("whip://120.12.32.12:8889/mystream/whip"), text: $createStreamWizard.customWhipUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.customWhipUrl) { _ in
                        updateUrlError()
                    }
            } header: {
                Text("URL")
            } footer: {
                FormFieldError(error: urlError)
            }
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
            createStreamWizard.customProtocol = .whip
            createStreamWizard.name = makeUniqueName(name: String(localized: "Custom WHIP"),
                                                     existingNames: model.database.streams)
        }
        .navigationTitle("WHIP")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
