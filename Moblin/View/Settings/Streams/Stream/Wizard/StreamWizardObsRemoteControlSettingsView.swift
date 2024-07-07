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
                    TextField("ws://213.33.45.132:4567", text: $model.wizardObsRemoteControlUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
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
                        .textInputAutocapitalization(.never)
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
                Section {
                    TextField("My source", text: $model.wizardObsRemoteControlSourceName)
                        .disableAutocorrection(true)
                } header: {
                    Text("Source name")
                } footer: {
                    Text("The name of the Source in OBS that receives the stream from Moblin.")
                }
                Section {
                    TextField("My BRB scene", text: $model.wizardObsRemoteControlBrbScene)
                        .disableAutocorrection(true)
                } header: {
                    Text("BRB scene")
                } footer: {
                    Text("""
                    The name of your BRB scene in OBS. Moblin will periodically try to switch \
                    to this scene if the stream is likely broken.
                    """)
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
