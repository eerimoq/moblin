import Foundation
import HaishinKit
import SwiftUI
import VideoToolbox

struct StreamButton: View {
    @ObservedObject var model = Model()

    var body: some View {
        if self.model.published {
            Button(action: {
                self.model.published.toggle()
                self.model.stopPublish()
            }, label: {
                Text("Stop")
            })
            .padding(5)
            .background(.red)
            .cornerRadius(10)
        } else {
            Button(action: {
                self.model.published.toggle()
                self.model.startPublish()
            }, label: {
                Text("Go live")
            })
            .padding(5)
            .background(.red)
            .cornerRadius(10)
        }
    }
}

struct ButtonImage: View {
    var image: String

    var body: some View {
        Image(systemName: self.image)
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
            self.action()
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
    }
}

struct ZoomSlider: View {
    var label: String
    var onChange: (_ level: CGFloat) -> Void

    @State var level: CGFloat = 1.0

    var body: some View {
        HStack {
            Text(self.label)
            Slider(
                value: Binding(get: {
                    self.level
                }, set: { (level) in
                    if level != self.level {
                        self.onChange(level)
                        self.level = level
                    }
                }),
                in: 1...5,
                step: 0.1
            )
        }
    }
}

struct ContentView: View {
    @ObservedObject var model = Model()

    private var videoView: VideoView!
    private var videoOverlayView: VideoOverlayView!
    @State private var mutedImage = "mic.fill"
    @State private var recordingImage = "record.circle"
    @State private var flashLightImage = "lightbulb"
    @State private var action: Int? = 0

    init() {
        model.config()
        videoView = VideoView(rtmpStream: $model.rtmpStream)
        videoOverlayView = VideoOverlayView(model: model)
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
                        Battery()
                        Spacer()
                        HStack {
                            Button(action: {
                                print("Settings")
                            }, label: {
                                NavigationLink(destination: SettingsView(model: self.model)) {
                                    ButtonImage(image: "gearshape")
                                }
                            })
                            GenericButton(image: mutedImage, action: {
                                if mutedImage == "mic.slash.fill" {
                                    mutedImage = "mic.fill"
                                } else {
                                    mutedImage = "mic.slash.fill"
                                }
                            })
                        }
                        HStack {
                            GenericButton(image: recordingImage, action: {
                                if recordingImage == "record.circle" {
                                    recordingImage = "record.circle.fill"
                                } else {
                                    recordingImage = "record.circle"
                                }
                            })
                            GenericButton(image: flashLightImage, action: {
                                model.toggleLight()
                                if flashLightImage == "lightbulb" {
                                    flashLightImage = "lightbulb.fill"
                                } else {
                                    flashLightImage = "lightbulb"
                                }
                            })
                        }
                        ZoomSlider(label: "B", onChange: { (level) in
                            print("back zoom level:", level)
                            model.setBackCameraZoomLevel(level: level)
                        })
                        ZoomSlider(label: "F", onChange: { (level) in
                            print("front zoom level:", level)
                        })
                        StreamButton(model: self.model)
                    }
                    .padding([.leading, .trailing, .top], 10)
                }
                .frame(width: 100)
                .background(.black)
            }
            .onAppear {
                self.model.registerForPublishEvent()
            }
            .onDisappear {
                self.model.unregisterForPublishEvent()
            }
            .foregroundColor(.white)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
