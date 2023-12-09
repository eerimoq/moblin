import SwiftUI
import WebKit

struct MainView: View {
    @EnvironmentObject var model: Model
    var streamView: StreamView

    private func settingsWidth(width: Double) -> Double {
        if model.settingsLayout == .full {
            return width
        } else {
            return settingsHalfWidth
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ZStack {
                    GeometryReader { metrics in
                        streamView
                            .ignoresSafeArea()
                            .onTapGesture(count: 1) { location in
                                guard model.database.tapToFocus else {
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
                                guard model.database.tapToFocus else {
                                    return
                                }
                                model.setAutoFocus()
                            })
                    }
                    StreamOverlayView()
                }
                .gesture(
                    MagnificationGesture()
                        .onChanged { amount in
                            model.changeZoomX(amount: Float(amount))
                        }
                        .onEnded { amount in
                            model.commitZoomX(amount: Float(amount))
                        }
                )
                ControlBarView()
            }
            if model.showingSettings {
                GeometryReader { metrics in
                    HStack {
                        if model.settingsLayout == .right {
                            Spacer()
                        }
                        NavigationStack {
                            SettingsView()
                        }
                        .frame(width: settingsWidth(width: metrics.size.width))
                        .background(Color(uiColor: .systemGroupedBackground))
                        if model.settingsLayout == .left {
                            Spacer()
                        }
                    }
                }
            }
            if model.showingBitrate {
                HStack {
                    Spacer()
                    NavigationStack {
                        StreamVideoBitrateSettingsButtonView(selection: model.stream
                            .bitrate)
                        {
                            model.showingBitrate = false
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.showingMic {
                HStack {
                    Spacer()
                    NavigationStack {
                        MicButtonView(selectedMic: model.mic) {
                            model.showingMic = false
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.showingObsScene {
                HStack {
                    Spacer()
                    NavigationStack {
                        ObsSceneView {
                            model.showingObsScene = false
                        }
                    }
                    .frame(width: settingsHalfWidth)
                }
            }
            if model.blackScreen {
                Text("")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    .onTapGesture(count: 2) { _ in
                        model.toggleBlackScreen()
                    }
            }
        }
        .onAppear {
            model.setup()
        }
        .toast(isPresenting: $model.showingToast, duration: 5) {
            model.toast
        }
    }
}
