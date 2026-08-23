import SwiftUI

struct StreamWizardCustomUsbSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        createStreamWizard.customUsbUrl.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.customUsbUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["usb"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(String("usb://localhost:7777"), text: $createStreamWizard.customUsbUrl)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.customUsbUrl) { _ in
                        updateUrlError()
                    }
            } header: {
                Text("URL")
            } footer: {
                VStack(alignment: .leading) {
                    FormFieldError(error: urlError)
                    Text("""
                    Only the port number matters. Connect this device to a computer with a USB cable \
                    and run the Moblin USB host tool on the computer to receive the stream.
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
            createStreamWizard.customProtocol = .usb
            if createStreamWizard.customUsbUrl.isEmpty {
                createStreamWizard.customUsbUrl = "usb://localhost:7777"
            }
            createStreamWizard.name = makeUniqueName(name: String(localized: "Custom USB"),
                                                     existingNames: model.database.streams)
        }
        .navigationTitle("USB")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
