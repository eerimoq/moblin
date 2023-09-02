import Foundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct ContentView: View {
    @ObservedObject var model = Model()
    private var videoView: StreamView!
    private var videoOverlayView: StreamOverlayView!

    init(settings: Settings) {
        model.setup(settings: settings)
        videoView = StreamView(rtmpStream: $model.rtmpStream)
        videoOverlayView = StreamOverlayView(model: model)
    }

    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                ZStack {
                    videoView
                        .ignoresSafeArea()
                    videoOverlayView
                }
                ControlBarView(model: model)
            }
            .onAppear {
                model.registerForPublishEvent()
            }
            .onDisappear {
                model.unregisterForPublishEvent()
            }
            .foregroundColor(.white)
        }
    }
}
