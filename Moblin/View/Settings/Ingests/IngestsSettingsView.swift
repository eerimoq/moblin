import SwiftUI

struct IngestsSettingsView: View {
    let database: Database

    var body: some View {
        Form {
            Section {
                RtmpServerSettingsView(rtmpServer: database.rtmpServer)
                SrtlaServerSettingsView(srtlaServer: database.srtlaServer)
                RistServerSettingsView(ristServer: database.ristServer)
                RtspClientSettingsView(rtspClient: database.rtspClient)
            }
        }
        .navigationTitle("Ingests")
    }
}
