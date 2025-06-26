import SwiftUI

struct StreamWizardNetworkSetupBelaboxSettingsView: View {
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.belaboxUrl.trim().isEmpty || !urlError.isEmpty
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.belaboxUrl)
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
                    text: $createStreamWizard.belaboxUrl
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onChange(of: createStreamWizard.belaboxUrl) { _ in
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
                    StreamWizardChatSettingsView(createStreamWizard: createStreamWizard)
                } label: {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            createStreamWizard.networkSetup = .belaboxCloudObs
            updateUrlError()
        }
        .navigationTitle("BELABOX cloud and OBS")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
