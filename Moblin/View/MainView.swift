import SwiftUI
import WebKit

enum SettingsLayout {
    case full
    case left
    case right
}

struct MainView: View {
    @EnvironmentObject var model: Model
    var streamView: StreamView
    @State private var showingSettings = false

    private func hideSettings() {
        showingSettings = false
    }

    private func showSettings() {
        showingSettings = true
    }

    private func settingsWidth(width: Double) -> Double {
        if model.settingsLayout == .full {
            return width
        } else {
            return 350
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
                            model.changeZoomLevel(amount: amount)
                        }
                        .onEnded { amount in
                            model.commitZoomLevel(amount: amount)
                        }
                )
                ControlBarView(showSettings: showSettings)
            }
            if showingSettings {
                GeometryReader { metrics in
                    HStack {
                        if model.settingsLayout == .right {
                            Spacer()
                        }
                        NavigationStack {
                            SettingsView(hideSettings: hideSettings)
                        }
                        .onAppear() {
                            if model.isLive {
                                model.makeToast(title: "Some settings disabled when Live")
                            }
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
                GeometryReader { metrics in
                    HStack {
                        Spacer()
                        StreamVideoBitrateSettingsButtonView(selection: model.stream
                            .bitrate)
                        {
                            model.showingBitrate = false
                        }
                        .frame(width: metrics.size.width * 0.5)
                    }
                }
            }
            if model.showingMic {
                GeometryReader { metrics in
                    HStack {
                        Spacer()
                        MicButtonView(selectedMic: model.mic) {
                            model.showingMic = false
                        }
                        .frame(width: metrics.size.width * 0.5)
                    }
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
