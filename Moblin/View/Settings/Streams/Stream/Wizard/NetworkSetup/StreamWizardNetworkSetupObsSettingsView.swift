import SwiftUI

struct StreamWizardNetworkSetupObsSettingsView: View {
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var portError = ""

    private func nextDisabled() -> Bool {
        return createStreamWizard.obsAddress.trim().isEmpty || createStreamWizard.obsPort.trim().isEmpty || !portError
            .isEmpty
    }

    private func updatePortError() {
        let port = createStreamWizard.obsPort.trim()
        if port.isEmpty {
            portError = ""
        } else if let port = UInt16(port), port > 0 {
            portError = ""
        } else {
            portError = String(localized: "Must be a number between 1 and 65535.")
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("213.33.45.132", text: $createStreamWizard.obsAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("IP address or domain name")
            } footer: {
                Text("Your public IP address if streaming over the internet.")
            }
            Section {
                TextField("7654", text: $createStreamWizard.obsPort)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: createStreamWizard.obsPort) { _ in
                        updatePortError()
                    }
            } header: {
                Text("Port")
            } footer: {
                VStack(alignment: .leading) {
                    FormFieldError(error: portError)
                    Text("Configure port forwarding in your router to forward incoming traffic to OBS.")
                }
            }
            Section {
                VStack(alignment: .leading) {
                    Text("1. Create a Media Source in OBS and configure it as shown in the image below.")
                    Text("")
                    Text("2. Replace 7654 with your port.")
                    HCenter {
                        Image("ObsMediaSourceSrt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            } header: {
                Text("Configure OBS on your computer")
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
            createStreamWizard.networkSetup = .obs
            updatePortError()
        }
        .navigationTitle("OBS")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
