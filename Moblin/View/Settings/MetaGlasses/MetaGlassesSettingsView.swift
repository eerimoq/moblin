import SwiftUI

struct MetaGlassesSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var metaGlasses: MetaGlassesState

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.metaGlasses.enabled
                }, set: { value in
                    model.database.metaGlasses.enabled = value
                    model.reloadMetaGlasses()
                }))
            }
            if model.database.metaGlasses.enabled {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(metaGlasses.registrationState.rawValue)
                            .foregroundColor(.secondary)
                    }
                    if metaGlasses.registrationState == .unregistered {
                        Button("Connect glasses") {
                            model.connectMetaGlasses()
                        }
                    } else if metaGlasses.registrationState == .registered {
                        Button("Disconnect glasses", role: .destructive) {
                            model.disconnectMetaGlasses()
                        }
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("""
                    Connect your Meta AI glasses through the Meta AI app. \
                    Make sure developer mode is enabled in the Meta AI app settings.
                    """)
                }
                Section {
                    Toggle("Auto start/stop streaming", isOn: Binding(get: {
                        model.database.metaGlasses.autoStartStopStreaming
                    }, set: { value in
                        model.database.metaGlasses.autoStartStopStreaming = value
                        model.objectWillChange.send()
                    }))
                } header: {
                    Text("Streaming")
                } footer: {
                    Text("""
                    Automatically start streaming from the glasses when switching \
                    to a scene using the Meta glasses camera, and stop when switching away.
                    """)
                }
                Section {
                    Toggle("Fill frame", isOn: Binding(get: {
                        model.database.metaGlasses.fillFrame
                    }, set: { value in
                        model.database.metaGlasses.fillFrame = value
                        model.objectWillChange.send()
                        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                    }))
                } header: {
                    Text("Display")
                } footer: {
                    Text("""
                    Fill the entire screen with the glasses video, cropping \
                    edges. When off, the full image is shown centered with \
                    black bars.
                    """)
                }
                Section {
                    Picker("Resolution", selection: Binding(get: {
                        model.database.metaGlasses.resolution
                    }, set: { (value: SettingsMetaGlassesResolution) in
                        guard value != model.database.metaGlasses.resolution else { return }
                        model.database.metaGlasses.resolution = value
                        model.objectWillChange.send()
                    })) {
                        ForEach(SettingsMetaGlassesResolution.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    Picker("Frame rate", selection: Binding(get: {
                        model.database.metaGlasses.frameRate
                    }, set: { (value: Int) in
                        guard value != model.database.metaGlasses.frameRate else { return }
                        model.database.metaGlasses.frameRate = value
                        model.objectWillChange.send()
                    })) {
                        Text("15").tag(15)
                        Text("24").tag(24)
                        Text("30").tag(30)
                    }
                } header: {
                    Text("Video")
                } footer: {
                    Text("""
                    Configure the video quality from the glasses camera. Higher \
                    resolution and frame rate use more battery on the glasses.
                    """)
                }
            }
        }
        .navigationTitle("Meta glasses")
    }
}
