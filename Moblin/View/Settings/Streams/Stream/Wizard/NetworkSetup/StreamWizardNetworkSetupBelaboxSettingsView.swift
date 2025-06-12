import SwiftUI

struct StreamWizardNetworkSetupBelaboxSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return model.wizardBelaboxUrl.trim().isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: model.wizardBelaboxUrl)
        if url.isEmpty {
            urlError = ""
        } else {
            urlError = isValidUrl(url: url, allowedSchemes: ["srt", "srtla"]) ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    "srtla://uk.srt.belabox.net:5000?streamid=jO4ijfFgrlpv4m2375msdoG3DDr2",
                    text: $model.wizardBelaboxUrl
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: model.wizardBelaboxUrl) { _ in
                    updateUrlError()
                }
            } header: {
                Text("Ingest URL")
            } footer: {
                VStack(alignment: .leading) {
                    FormFieldError(error: urlError)
                    Text("""
                    Press "Add automatically to Moblin" on https://cloud.belabox.net SRT(LA) relays \
                    (requires login). See screenshot below.
                    """)
                    HCenter {
                        Image("BelaboxCloudIngest")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 400)
                    }
                }
            }
            Section {
                NavigationLink {
                    StreamWizardChatSettingsView()
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .belaboxCloudObs
            updateUrlError()
        }
        .navigationTitle("BELABOX cloud and OBS")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
