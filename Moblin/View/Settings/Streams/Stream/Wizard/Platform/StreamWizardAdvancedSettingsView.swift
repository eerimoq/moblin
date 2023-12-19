import SwiftUI

struct StreamWizardAdvancedSettingsView: View {
    @EnvironmentObject private var model: Model

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $model.wizardName)
            } header: {
                Text("Stream name")
            }
            Section {
                HStack {
                    Spacer()
                    Button {
                        model.isPresentingWizard = false
                    } label: {
                        Text("Create")
                    }
                    .disabled(model.wizardName.isEmpty)
                    Spacer()
                }
            }
        }
        .navigationTitle("Advanced")
        .toolbar {
            CreateStreamWizardToolbar()
        }
    }
}
