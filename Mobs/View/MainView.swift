import AlertToast
import Foundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct MainView: View {
    @ObservedObject var model = Model()
    private var streamView: StreamView!

    init(settings: Settings) {
        model.setup(settings: settings)
        streamView = StreamView(model: model)
    }

    var body: some View {
        NavigationStack {
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
        }
        .toast(isPresenting: $model.showToast, duration: 5) {
            model.toast
        }
    }
}
