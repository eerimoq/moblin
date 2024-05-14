import SwiftUI

struct StreamWizardCustomRistSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return model.wizardCustomRistUrl.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: model.wizardCustomRistUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(
                url: url,
                allowedSchemes: ["rist"],
                rtmpStreamKeyRequired: false
            ) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("rist://120.35.234.2:2030", text: $model.wizardCustomRistUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: model.wizardCustomRistUrl) { _ in
                        updateUrlError()
                    }
            } header: {
                Text("Url")
            } footer: {
                FormFieldError(error: urlError)
            }
            Section {
                NavigationLink(destination: StreamWizardSummarySettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardCustomProtocol = .rist
            model.wizardName = "Custom RIST"
        }
        .navigationTitle("RIST")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
