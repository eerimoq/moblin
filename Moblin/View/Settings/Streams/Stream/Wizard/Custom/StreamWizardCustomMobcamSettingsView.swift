import SwiftUI

struct StreamWizardCustomMobcamSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        createStreamWizard.customMobcamUrl.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.customMobcamUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["mobcam"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(String("mobcam://localhost:7777"), text: $createStreamWizard.customMobcamUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.customMobcamUrl) { _ in
                        updateUrlError()
                    }
            } header: {
                Text("URL")
            } footer: {
                VStack(alignment: .leading) {
                    FormFieldError(error: urlError)
                    Text("""
                    Only the port number matters. Connect this device to a computer with a USB cable \
                    and run the Moblin Mobcam host tool on the computer to receive the stream.
                    """)
                }
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
            createStreamWizard.customProtocol = .mobcam
            if createStreamWizard.customMobcamUrl.isEmpty {
                createStreamWizard.customMobcamUrl = "mobcam://localhost:7777"
            }
            createStreamWizard.name = makeUniqueName(name: String(localized: "Custom Mobcam"),
                                                     existingNames: model.database.streams)
        }
        .navigationTitle("Mobcam")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
