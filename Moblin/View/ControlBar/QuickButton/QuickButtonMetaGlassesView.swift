import SwiftUI

struct QuickButtonMetaGlassesView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var metaGlasses: MetaGlassesState

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Registration")
                    Spacer()
                    Text(metaGlasses.registrationState.toString())
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Streaming")
                    Spacer()
                    Text(metaGlasses.streamingState.toString())
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Status")
            }
            if metaGlasses.registrationState == .registered {
                Section {
                    if metaGlasses.streamingState == .stopped {
                        Button("Start streaming") {
                            model.startMetaGlassesStreaming()
                        }
                    } else {
                        Button("Stop streaming", role: .destructive) {
                            model.stopMetaGlassesStreaming()
                        }
                    }
                }
            } else if metaGlasses.registrationState == .unregistered {
                Section {
                    Button("Connect glasses") {
                        model.connectMetaGlasses()
                    }
                } footer: {
                    Text("You will be redirected to the Meta AI app to confirm the connection.")
                }
            }
            ShortcutSectionView {
                NavigationLink {
                    MetaGlassesSettingsView(metaGlasses: model.metaGlasses)
                } label: {
                    Label("Meta glasses", systemImage: "eyeglasses")
                }
            }
        }
        .navigationTitle("Meta glasses")
    }
}
