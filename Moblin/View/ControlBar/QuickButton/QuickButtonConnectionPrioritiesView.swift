import Foundation
import SwiftUI

private struct NoConnectionPrioritiesView: View {
    let protocolName: String

    var body: some View {
        Form {
            Section {
                Text("""
                Connection priorities are not supported by \(protocolName). Only SRTLA supports \
                connection priorities.
                """)
            }
        }
        .navigationTitle("Connection priorities")
    }
}

struct QuickButtonConnectionPrioritiesView: View {
    @ObservedObject var stream: SettingsStream

    var body: some View {
        switch stream.getProtocol() {
        case .srt:
            StreamSrtConnectionPriorityView(stream: stream)
        default:
            NoConnectionPrioritiesView(protocolName: stream.protocolString())
        }
    }
}
