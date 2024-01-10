import SwiftUI

struct StreamWizardObsRemoteControlSettingsView: View {
    @EnvironmentObject private var model: Model
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        if model.wizardObsRemoteControlEnabled {
            if model.wizardObsRemoteControlUrl.isEmpty || model.wizardObsRemoteControlPassword
                .isEmpty || !urlError.isEmpty
            {
                return true
            }
        }
        return false
    }

    private func updateUrlError() {
        let url = cleanUrl(url: model.wizardObsRemoteControlUrl)
        if let message = isValidWebSocketUrl(url: url) {
            urlError = message
        } else {
            urlError = ""
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.wizardObsRemoteControlEnabled, label: {
                    Text("Enabled")
                })
            }
            if model.wizardObsRemoteControlEnabled {
                Section {
                    TextField("ws://213.33.45.132", text: $model.wizardObsRemoteControlUrl)
                        .disableAutocorrection(true)
                        .onChange(of: model.wizardObsRemoteControlUrl) { _ in
                            updateUrlError()
                        }
                } header: {
                    Text("URL")
                } footer: {
                    VStack(alignment: .leading) {
                        FormFieldError(error: urlError)
                        Text("Use your public IP address if streaming over the internet.")
                        Text("")
                        Text("Configure port forwarding in your router to forward incoming traffic to OBS.")
                    }
                }
                Section {
                    TextField("po3Gg4pflp3s", text: $model.wizardObsRemoteControlPassword)
                        .disableAutocorrection(true)
                } header: {
                    Text("Password")
                } footer: {
                    VStack(alignment: .leading) {
                        Text(
                            """
                            Copy from OBS Show Connect Info as seen in the screenshot below. \
                            Tools → WebSocket Server Settings → Show Connect Info → Server Password.
                            """
                        )
                        HStack {
                            Spacer()
                            Image("ObsRemoteControl")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                            Spacer()
                        }
                    }
                }
            }
            Section {
                NavigationLink(destination: StreamWizardSummarySettingsView()) {
                    WizardNextButtonView()
                        .disabled(nextDisabled())
                }
            }
        }
        .onAppear {
            updateUrlError()
        }
        .navigationTitle("OBS remote control")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
