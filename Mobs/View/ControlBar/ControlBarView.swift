//
//  ControlBarView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-30.
//

import SwiftUI

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

var mutedImageOn = "mic.slash.fill"
var mutedImageOff = "mic.fill"
var recordingImageOn = "record.circle.fill"
var recordingImageOff = "record.circle"
var flashImageOn = "lightbulb.fill"
var flashImageOff = "lightbulb"

struct ControlBarView: View {
    @ObservedObject var model: Model
    @State private var mutedImage = mutedImageOff
    @State private var recordingImage = recordingImageOff
    @State private var flashLightImage = flashImageOff
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    BatteryView(level: model.batteryLevel)
                    Spacer()
                    Text(model.currentTime)
                        .font(.system(size: 13))
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
                ZoomView(onChange: { (level) in
                    model.setBackCameraZoomLevel(level: level)
                })
                StreamButton(model: model)
                    .padding([.top], 10)
            }
            .padding([.leading, .trailing, .top], 10)
        }
        .frame(width: 100)
        .background(.black)
    }
}

struct ControlBarView_Previews: PreviewProvider {
    static var previews: some View {
        ControlBarView(model: Model())
    }
}
