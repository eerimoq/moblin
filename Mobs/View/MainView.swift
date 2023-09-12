import Foundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct MainView: View {
    @ObservedObject var model = Model()
    private var streamView: StreamView!
    private var streamOverlayView: StreamOverlayView!

    init(settings: Settings) {
        model.setup(settings: settings)
        streamView = StreamView(rtmpStream: $model.rtmpStream)
        streamOverlayView = StreamOverlayView(model: model)
    }

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                ZStack {
                    streamView
                        .ignoresSafeArea()
                    streamOverlayView
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
