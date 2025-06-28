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
    @EnvironmentObject var model: Model

    var body: some View {
        switch model.stream.getProtocol() {
        case .srt:
            StreamSrtConnectionPriorityView(stream: model.stream)
        default:
            NoConnectionPrioritiesView(protocolName: model.stream.protocolString())
        }
    }
}
