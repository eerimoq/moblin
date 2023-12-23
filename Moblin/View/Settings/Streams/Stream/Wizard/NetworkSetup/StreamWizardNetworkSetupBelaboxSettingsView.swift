import SwiftUI

struct StreamWizardNetworkSetupBelaboxSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField(
                    "srtla://uk.srt.belabox.net:5000?streamid=jO4ijfFgrlpv4m2375msdoG3DDr2",
                    text: $model.wizardBelaboxUrl
                )
                .disableAutocorrection(true)
            } header: {
                Text("Ingest URL")
            } footer: {
                Text("""
                Copy from https://cloud.belabox.net SRT(LA) relays (requires login). \
                See image below for example. Replace srt:// with srtla:// and change port \
                to use SRTLA instead of SRT.
                """)
            }
            Section {
                HStack {
                    Spacer()
                    Image("BelaboxCloudIngest")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Spacer()
                }
            }
            Section {
                NavigationLink(destination: StreamWizardGeneralSettingsView()) {
                    WizardNextButtonView()
                }
                .disabled(model.wizardBelaboxUrl.isEmpty)
            }
        }
        .onAppear {
            model.wizardNetworkSetup = .belaboxCloudObs
        }
        .navigationTitle("BELABOX cloud and OBS")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
