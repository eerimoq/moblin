import SwiftUI

struct StreamWizardNetworkSetupObsSettingsView: View {
    @EnvironmentObject private var model: Model

    private func isDisabled() -> Bool {
        return model.wizardObsAddress.isEmpty || model.wizardObsPort.isEmpty
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
            } header: {
                Text("Port")
            } footer: {
                Text("Configure port forwarding in your router to forward incoming traffic to OBS.")
            }
            Section {
                VStack(alignment: .leading) {
                    Text("Create a Media Source in OBS and configure it as shown below.")
                    Text("")
                    Text("Replace 192.168.50.72 with your local IP address (typically 192.168.x.y).")
                    Text("")
                    Text("Replace 7654 with your port.")
                }
            }
            Section {
                HStack {
                    Spacer()
                    Image("ObsMediaSourceSrt")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Spacer()
                }
            }
            Section {
                NavigationLink(destination: StreamWizardGeneralSettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(isDisabled())
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .obs
        }
        .navigationTitle("OBS")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
