import SwiftUI

struct IngestsSettingsView: View {
    let database: Database

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    RtmpServerSettingsView(rtmpServer: database.rtmpServer)
                } label: {
                    Text("RTMP server")
                }
                NavigationLink {
                    SrtlaServerSettingsView(srtlaServer: database.srtlaServer)
                } label: {
                    Text("SRT(LA) server")
                }
                NavigationLink {
                    RistServerSettingsView(ristServer: database.ristServer)
                } label: {
                    Text("RIST server")
                }
                NavigationLink {
                    RtspClientSettingsView(rtspClient: database.rtspClient)
                } label: {
                    Text("RTSP client")
                }
            }
        }
        .navigationTitle("Ingests")
    }
}
