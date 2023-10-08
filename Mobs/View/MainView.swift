import AlertToast
import Foundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct MainView: View {
    @ObservedObject var model = Model()
    private var streamView: StreamView!
    @State private var currentAmount = 0.0
    @State private var finalAmount = 1.0

    init() {
        model.setup()
        streamView = StreamView(model: model)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HStack(spacing: 0) {
                    ZStack {
                        streamView
                            .ignoresSafeArea()
                        StreamOverlayView(model: model)
                    }
                    .gesture(
                        MagnificationGesture(minimumScaleDelta: 0.0)
                            .onChanged { amount in
                                model.changeZoomLevel(amount: amount)
                            }
                            .onEnded({ amount in
                                model.commitZoomLevel(amount: amount)
                            }))
                    ControlBarView(model: model)
                }
                if model.showingBitrate {
                    GeometryReader { metrics in
                        HStack {
                            Spacer()
                            StreamVideoBitrateSettingsButtonView(model: model, done: {
                                model.showingBitrate = false
                            })
                            .frame(width: metrics.size.width * 0.5)
                        }
                    }
                }
                if model.showingMic {
                    GeometryReader { metrics in
                        HStack {
                            Spacer()
                            MicButtonView(model: model, done: {
                                model.showingMic = false
                            })
                            .frame(width: metrics.size.width * 0.5)
                        }
                    }
                }
            }
            .onAppear {
                AppDelegate.setAllowedOrientations(mask: .landscapeRight)
            }
            .onDisappear {
                AppDelegate.setAllowedOrientations(mask: .all)
            }
        }
        .toast(isPresenting: $model.showingToast, duration: 5) {
            model.toast
        }
    }
}
