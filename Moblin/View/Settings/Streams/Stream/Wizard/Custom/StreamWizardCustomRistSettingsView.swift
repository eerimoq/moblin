import SwiftUI

struct StreamWizardCustomRistSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.customRistUrl.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.customRistUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["rist"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("rist://120.35.234.2:2030", text: $createStreamWizard.customRistUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.customRistUrl) { _ in
                        updateUrlError()
                    }
            } header: {
                Text("Url")
            } footer: {
                FormFieldError(error: urlError)
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
            createStreamWizard.customProtocol = .rist
            createStreamWizard.name = makeUniqueName(name: String(localized: "Custom RIST"),
                                                     existingNames: model.database.streams)
        }
        .navigationTitle("RIST")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
