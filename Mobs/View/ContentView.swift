import Foundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct StreamButtonText: View {
    var text: String
    
    var body: some View {
        Text(text)
            .frame(width: 60)
            .padding(5)
            .background(.red)
            .cornerRadius(10)
    }
}

struct StreamButton: View {
    @ObservedObject var model: Model

    var body: some View {
        switch model.liveState {
        case .stopped:
            Button(action: {
                model.startStream()
            }, label: {
                StreamButtonText(text: "Go Live")
            })
            .disabled(model.connection == nil)
        case .live:
            Button(action: {
                model.stopStream()
            }, label: {
                StreamButtonText(text: "Stop")
            })
        }
    }
}

struct ButtonImage: View {
    var image: String

    var body: some View {
        Image(systemName: image)
            .frame(width: 40, height: 40)
            .background(.blue)
            .clipShape(Circle())
    }
}

struct GenericButton: View {
    var image: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }, label: {
            ButtonImage(image: self.image)
        })
    }
}

struct Battery: View {
    var body: some View {
        Rectangle()
            .fill(.green)
            .frame(width: 30, height: 15)
            .cornerRadius(5)
    }
}

struct ZoomSlider: View {
    var onChange: (_ level: CGFloat) -> Void
    @State var level: CGFloat = 1.0

    var body: some View {
        Slider(
            value: Binding(get: {
                level
            }, set: { (level) in
                if level != self.level {
                    onChange(level)
                    self.level = level
                }
            }),
            in: 1...5,
            step: 0.1
        )
    }
}

var mutedImageOn = "mic.slash.fill"
var mutedImageOff = "mic.fill"
var recordingImageOn = "record.circle.fill"
var recordingImageOff = "record.circle"
var flashImageOn = "lightbulb.fill"
var flashImageOff = "lightbulb"

struct ContentView: View {
    @ObservedObject var model = Model()

    private var videoView: StreamView!
    private var videoOverlayView: StreamOverlayView!
    @State private var mutedImage = mutedImageOff
    @State private var recordingImage = recordingImageOff
    @State private var flashLightImage = flashImageOff

    init(settings: Settings) {
        model.config(settings: settings)
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
                VStack {
                    VStack {
                        HStack {
                            Text(model.currentTime)
                                .font(.system(size: 13))
                            Battery()
                        }
                        Spacer()
                        HStack {
                            GenericButton(image: "ellipsis", action: {
                            })
                            Button(action: {
                                print("Settings")
                            }, label: {
                                NavigationLink(destination: SettingsView(model: model)) {
                                    ButtonImage(image: "gearshape")
                                }
                            })
                        }
                        HStack {
                            GenericButton(image: "figure.wave", action: {
                            })
                            GenericButton(image: "hand.thumbsup.fill", action: {
                            })
                        }
                        HStack {
                            GenericButton(image: "music.note", action: {
                            })
                            GenericButton(image: mutedImage, action: {
                                model.toggleMute()
                                if mutedImage == mutedImageOn {
                                    mutedImage = mutedImageOff
                                } else {
                                    mutedImage = mutedImageOn
                                }
                            })
                        }
                        HStack {
                            GenericButton(image: recordingImage, action: {
                                if recordingImage == recordingImageOff {
                                    recordingImage = recordingImageOn
                                } else {
                                    recordingImage = recordingImageOff
                                }
                            })
                            GenericButton(image: flashLightImage, action: {
                                model.toggleLight()
                                if flashLightImage == flashImageOff {
                                    flashLightImage = flashImageOn
                                } else {
                                    flashLightImage = flashImageOff
                                }
                            })
                        }
                        ZoomSlider(onChange: { (level) in
                            model.setBackCameraZoomLevel(level: level)
                        })
                        StreamButton(model: model)
                    }
                    .padding([.leading, .trailing, .top], 10)
                }
                .frame(width: 100)
                .background(.black)
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(settings: Settings())
    }
}
