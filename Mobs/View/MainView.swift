import SwiftUI
import WebKit

struct MainView: View {
    @ObservedObject var model: Model
    private var streamView: StreamView!

    init(model: Model) {
        self.model = model
        streamView = StreamView(model: model)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HStack(spacing: 0) {
                    ZStack {
                        GeometryReader { metrics in
                            streamView
                                .ignoresSafeArea()
                                .onTapGesture(count: 1) { location in
                                    guard model.database.tapToFocus! else {
                                        return
                                    }
                                    let x = (location.x / metrics.size.width)
                                        .clamped(to: 0 ... 1)
                                    let y = (location.y / metrics.size.height)
                                        .clamped(to: 0 ... 1)
                                    model.setFocusPointOfInterest(focusPoint: CGPoint(
                                        x: x,
                                        y: y
                                    ))
                                }
                                .onLongPressGesture(perform: {
                                    guard model.database.tapToFocus! else {
                                        return
                                    }
                                    model.setAutoFocus()
                                })
                        }
                        StreamOverlayView(model: model)
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { amount in
                                model.changeZoomLevel(amount: amount)
                            }
                            .onEnded { amount in
                                model.commitZoomLevel(amount: amount)
                            }
                    )
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
                AppDelegate.orientationLock = .landscapeRight
            }
            .onDisappear {
                AppDelegate.orientationLock = .all
            }
        }
        .toast(isPresenting: $model.showingToast, duration: 5) {
            model.toast
        }
    }
}
