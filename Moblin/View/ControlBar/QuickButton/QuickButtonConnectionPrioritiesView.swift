import Foundation
import SwiftUI

struct QuickButtonConnectionPrioritiesView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        switch model.stream.getProtocol() {
        case .srt:
            StreamSrtConnectionPriorityView(stream: model.stream)
        default:
            EmptyView()
        }
    }
}
