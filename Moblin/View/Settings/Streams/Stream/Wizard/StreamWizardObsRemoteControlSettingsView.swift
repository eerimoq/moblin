import SwiftUI

struct StreamWizardObsRemoteControlSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard
    @State var urlError = ""

    private func nextDisabled() -> Bool {
        if createStreamWizard.obsRemoteControlEnabled {
            if createStreamWizard.obsRemoteControlUrl.isEmpty || createStreamWizard.obsRemoteControlPassword
                .isEmpty || !urlError.isEmpty
            {
                return true
            }
        }
        return false
    }

    private func updateUrlError() {
        let url = cleanUrl(url: createStreamWizard.obsRemoteControlUrl)
        if let message = isValidWebSocketUrl(url: url) {
            urlError = message
        } else {
            urlError = ""
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $createStreamWizard.obsRemoteControlEnabled, label: {
                    Text("Enabled")
                })
            }
            if createStreamWizard.obsRemoteControlEnabled {
                Section {
                    TextField("ws://213.33.45.132:4567", text: $createStreamWizard.obsRemoteControlUrl)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onChange(of: createStreamWizard.obsRemoteControlUrl) { _ in
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
                    TextField("po3Gg4pflp3s", text: $createStreamWizard.obsRemoteControlPassword)
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
                    TextField("My BRB scene", text: $createStreamWizard.obsRemoteControlBrbScene)
                        .disableAutocorrection(true)
                } header: {
                    Text("BRB scene")
                } footer: {
                    Text("""
                    The name of your BRB scene in OBS. Moblin will periodically try to switch \
                    to this scene if the stream is likely broken.
                    """)
                }
                Section {
                    TextField("My source", text: $createStreamWizard.obsRemoteControlSourceName)
                        .disableAutocorrection(true)
                } header: {
                    Text("Source name")
                } footer: {
                    Text("The name of the Source in OBS that receives the stream from Moblin.")
                }
            }
            Section {
                NavigationLink {
                    StreamWizardSummarySettingsView(createStreamWizard: createStreamWizard)
                } label: {
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
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
