import SwiftUI

struct StreamWizardMobcamSettingsView: View {
    let model: Model
    @ObservedObject var createStreamWizard: CreateStreamWizard

    var body: some View {
        Form {
            Section {
                Text("Use Moblin as a low latency camera in OBS Studio over USB.")
            }
            Section {
                VStack(alignment: .leading) {
                    Text("""
                    1. Install the OBS Mobcam Plugin as described \
                    [here](https://github.com/eerimoq/mobcam/tree/main/crates/obs-plugin#mobcam-obs-plugin).
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
            }
        }
        .onAppear {
            createStreamWizard.platform = .mobcam
            createStreamWizard.name = makeUniqueName(name: String(localized: "Custom Mobcam"),
                                                     existingNames: model.database.streams)
        }
        .navigationTitle("Mobcam")
        .toolbar {
            CreateStreamWizardToolbar(createStreamWizard: createStreamWizard)
        }
    }
}
