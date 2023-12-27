import SwiftUI

struct RtmpServerSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.rtmpServer!.enabled
                }, set: { value in
                    model.database.rtmpServer!.enabled = value
                    model.store()
                    model.reloadRtmpServer()
                }))
            }
            Section {
                HStack {
                    Text("rtmp://10.0.0.8:1935/camera/")
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = "rtmp://10.0.0.8:1935/camera/"
                        model.makeToast(title: "Copied to clipboard")
                    }, label: {
                        Image(systemName: "doc.on.doc")
                    })
                }
                HStack {
                    Text("rtmp://12.132.10.27:1935/camera/")
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = "rtmp://12.132.10.27:1935/camera/"
                        model.makeToast(title: "Copied to clipboard")
                    }, label: {
                        Image(systemName: "doc.on.doc")
                    })
                }
            } header: {
                Text("URLs")
            }
            Section {
                List {
                    ForEach(model.database.rtmpServer!.streams) { stream in
                        NavigationLink(destination: RtmpServerStreamSettingsView(stream: stream)) {
                            Text(stream.name)
                        }
                    }
                }
                CreateButtonView(action: {
                    model.database.rtmpServer!.streams.append(SettingsRtmpServerStream())
                    model.store()
                })
            } header: {
                Text("Streams")
            }
        }
        .navigationTitle("RTMP server")
        .toolbar {
            SettingsToolbar()
        }
    }
}
