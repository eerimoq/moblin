import SwiftUI

struct StreamWizardNetworkSetupObsSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var portError = ""

    private func nextDisabled() -> Bool {
        return model.wizardObsAddress.trim().isEmpty || model.wizardObsPort.trim().isEmpty || !portError
            .isEmpty
    }

    private func updatePortError() {
        model.wizardObsPort = model.wizardObsPort.trim()
        if model.wizardObsPort.isEmpty {
            portError = ""
        } else if let port = UInt16(model.wizardObsPort), port > 0 {
            portError = ""
        } else {
            portError = String(localized: "Must be a number between 1 and 65535.")
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("213.33.45.132", text: $model.wizardObsAddress)
                    .disableAutocorrection(true)
            } header: {
                Text("IP address or domain name")
            } footer: {
                Text("Your public IP address if streaming over the internet.")
            }
            Section {
                TextField("7654", text: $model.wizardObsPort)
                    .disableAutocorrection(true)
                    .onSubmit {
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
                    Text("2. Replace 192.168.50.72 with your local IP address (typically 192.168.x.y).")
                    Text("")
                    Text("3. Replace 7654 with your port.")
                    HStack {
                        Spacer()
                        Image("ObsMediaSourceSrt")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                        Spacer()
                    }
                }
            } header: {
                Text("Configure OBS on your computer")
            }
            Section {
                NavigationLink(destination: StreamWizardChatSettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(nextDisabled())
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .obs
            updatePortError()
        }
        .navigationTitle("OBS")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
