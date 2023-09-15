import Foundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct MainView: View {
    @ObservedObject var model = Model()
    private var streamView: StreamView!

    init(settings: Settings) {
        logger.info("main view init")
        model.setup(settings: settings)
        streamView = StreamView(netStream: $model.netStream)
    }

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                ZStack {
                    streamView
                        .ignoresSafeArea()
                    StreamOverlayView(model: model)
                }
                ControlBarView(model: model)
            }
            .onAppear {
                AppDelegate.setAllowedOrientations(mask: .landscapeRight)
            }
            .onDisappear {
                AppDelegate.setAllowedOrientations(mask: .all)
            }
            .foregroundColor(.white)
        }
    }
}
