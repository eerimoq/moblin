import SwiftUI

struct StreamWizardMobcamSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        createStreamWizard.mobcamUrl.isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.mobcamUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["mobcam"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    String("mobcam://localhost:\(DefaultTcpPorts.mobcamStream)"),
                    text: $createStreamWizard.mobcamUrl
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: createStreamWizard.mobcamUrl) { _ in
                    updateUrlError()
                }
            } header: {
                Text("URL")
            } footer: {
                FormFieldError(error: urlError)
            }
            Section {
                VStack(alignment: .leading) {
                    Text("""
                    1. Install the OBS Mobcam Plugin as described \
                    [here](https://github.com/eerimoq/obs-mobcam-plugin#obs-mobcam-plugin).
                    """)
                    Text("")
                    Text("2. Connect Moblin to the computer with a USB cable.")
                    Text("")
                    Text("3. Add a Mobcam source in OBS.")
                    Text("")
                    Text("4. Press Go live in Moblin to start the stream to OBS.")
                }
            } header: {
                Text("Configure OBS on your computer")
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
            createStreamWizard.platform = .mobcam
            if createStreamWizard.mobcamUrl.isEmpty {
                createStreamWizard.mobcamUrl = "mobcam://localhost:\(DefaultTcpPorts.mobcamStream)"
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
