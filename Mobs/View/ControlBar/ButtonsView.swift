//
//  ButtonsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-31.
//

import SwiftUI

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
var monochromeEffectImageOn = "popcorn.fill"
var monochromeEffectImageOff = "popcorn"
var iconEffectImageOn = "photo.fill"
var iconEffectImageOff = "photo"

struct ButtonsView: View {
    @ObservedObject var model: Model
    @State private var mutedImage = mutedImageOff
    @State private var recordingImage = recordingImageOff
    @State private var flashLightImage = flashImageOff
    @State private var monochromeEffectImage = monochromeEffectImageOff
    @State private var iconEffectImage = iconEffectImageOff
    
    var body: some View {
        VStack {
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
                GenericButton(image: iconEffectImage, action: {
                    if iconEffectImage == iconEffectImageOn {
                        model.iconEffectOff()
                        iconEffectImage = iconEffectImageOff
                    } else {
                        model.iconEffectOn()
                        iconEffectImage = iconEffectImageOn
                    }
                })
                GenericButton(image: "hand.thumbsup.fill", action: {
                })
            }
            HStack {
                GenericButton(image: monochromeEffectImage, action: {
                    if monochromeEffectImage == monochromeEffectImageOn {
                        model.monochromeEffectOff()
                        monochromeEffectImage = monochromeEffectImageOff
                    } else {
                        model.monochromeEffectOn()
                        monochromeEffectImage = monochromeEffectImageOn
                    }
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
        }
    }
}

struct ButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonsView(model: Model())
    }
}
