import SwiftUI
import WebKit
/*
 struct WebView2: UIViewRepresentable {
     let url: URL

     func makeUIView(context _: Context) -> WKWebView {
         let configuration = WKWebViewConfiguration()
         configuration.allowsInlineMediaPlayback = true
         //configuration.allowsAirPlayForMediaPlayback = true
         //configuration.allowsPictureInPictureMediaPlayback = false
         configuration.mediaTypesRequiringUserActionForPlayback = []
         let wkwebView = WKWebView(frame: CGRect(x: 0, y: 0, width: 200, height: 200),
        configuration: configuration)
         wkwebView.load(URLRequest(url: url))
         return wkwebView
     }

     func updateUIView(_: WKWebView, context _: Context) {}
 }*/

struct MainView: View {
    @ObservedObject var model = Model()
    private var streamView: StreamView!

    init() {
        model.setup()
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
                                .onTapGesture(count: 2) { _ in
                                    guard model.database.tapToFocus! else {
                                        return
                                    }
                                    model.setAutoFocus()
                                }
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
                        }
                        StreamOverlayView(model: model)
                    }
                    .gesture(
                        MagnificationGesture(minimumScaleDelta: 0.0)
                            .onChanged { amount in
                                model.changeZoomLevel(amount: amount)
                            }
                            .onEnded { amount in
                                model.commitZoomLevel(amount: amount)
                            }
                    )
                    ControlBarView(model: model)
                }
                // WebView2(url: URL(string: "https://sr.se")!)
                // WebView2(url: URL(string:
                // "https://videojs.github.io/autoplay-tests/plain/attr/autoplay-muted.html")!)
                // WebView2(url: URL(string: "https://videojs.github.io/autoplay-tests/plain/play/autoplay.html")!)
                // WebView2(url: URL(string:
                // "https://file-examples.com/storage/feaade38c1651bd01984236/2017/11/file_example_MP3_700KB.mp3")!)
                // .frame(width: 200, height: 200)
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
