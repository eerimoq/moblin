//
//  ButtonsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-31.
//

import SwiftUI

struct ButtonImage: View {
    var image: String
    var on: Bool = false
    
    var body: some View {
        let image = Image(systemName: image)
            .frame(width: 40, height: 40)
            .foregroundColor(.white)
            .background(.blue)
            .clipShape(Circle())
        if on {
            image.overlay(
                Circle()
                    .stroke(.white)
            )
        } else {
            image
        }
    }
}

struct GenericButton: View {
    var image: String
    var action: () -> Void
    var on: Bool = false

    var body: some View {
        Button(action: {
            action()
        }, label: {
            ButtonImage(image: image, on: on)
        })
    }
}

var mutedImageOn = "mic.slash"
var mutedImageOff = "mic"
var recordingImageOn = "record.circle.fill"
var recordingImageOff = "record.circle"
var flashImageOn = "lightbulb.fill"
var flashImageOff = "lightbulb"
var monochromeEffectImageOn = "moon.fill"
var monochromeEffectImageOff = "moon"
var iconEffectImageOn = "photo.fill"
var iconEffectImageOff = "photo"
var movieEffectImageOn = "film.fill"
var movieEffectImageOff = "film"

struct ButtonsView: View {
    @ObservedObject var model: Model
    @State private var mutedImage = mutedImageOff
    @State private var recordingImage = recordingImageOff
    @State private var flashLightImage = flashImageOff
    @State private var monochromeEffectImage = monochromeEffectImageOff
    @State private var iconEffectImage = iconEffectImageOff
    @State private var movieEffectImage = movieEffectImageOff
    
    var body: some View {
        VStack {
            HStack {
                GenericButton(image: "ellipsis", action: {
                })
                Button(action: {
                    logger.error("Settings")
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
                }, on: iconEffectImage == iconEffectImageOn)
                GenericButton(image: movieEffectImage, action: {
                    if movieEffectImage == movieEffectImageOn {
                        model.movieEffectOff()
                        movieEffectImage = movieEffectImageOff
                    } else {
                        model.movieEffectOn()
                        movieEffectImage = movieEffectImageOn
                    }
                }, on: movieEffectImage == movieEffectImageOn)
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
                }, on: monochromeEffectImage == monochromeEffectImageOn)
                GenericButton(image: mutedImage, action: {
                    model.toggleMute()
                    if mutedImage == mutedImageOn {
                        mutedImage = mutedImageOff
                    } else {
                        mutedImage = mutedImageOn
                    }
                }, on: mutedImage == mutedImageOn)
            }
            HStack {
                GenericButton(image: recordingImage, action: {
                    if recordingImage == recordingImageOff {
                        recordingImage = recordingImageOn
                    } else {
                        recordingImage = recordingImageOff
                    }
                }, on: recordingImage == recordingImageOn)
                GenericButton(image: flashLightImage, action: {
                    model.toggleLight()
                    if flashLightImage == flashImageOff {
                        flashLightImage = flashImageOn
                    } else {
                        flashLightImage = flashImageOff
                    }
                }, on: flashLightImage == flashImageOn)
            }
        }
    }
}
