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

struct ButtonPlaceholderImage: View {
    var body: some View {
        Image(systemName: "pawprint")
            .frame(width: 40, height: 40)
            .foregroundColor(.black)
    }
}

struct ButtonView: View {
    @ObservedObject var model: Model
    private var state: ButtonState
    private var button: SettingsButton
    @State private var image: String
    private var actionOn: () -> Void
    private var actionOff: () -> Void

    init(model: Model, state: ButtonState, button: SettingsButton) {
        self.model = model
        self.state = state
        self.button = button
        if state.isOn {
            self.image = state.imageOn
        } else {
            self.image = state.imageOff
        }
        switch button.type {
        case "Torch":
            self.actionOn = {
                model.toggleTorch()
            }
            self.actionOff = {
                model.toggleTorch()
            }
        case "Mute":
            self.actionOn = {
                model.toggleMute()
            }
            self.actionOff = {
                model.toggleMute()
            }
        case "Widget":
            self.actionOn = {
                model.movieEffectOn()
            }
            self.actionOff = {
                model.movieEffectOff()
            }
        default:
            fatalError("Unknown button type \(button.type)")
        }
    }
    
    var body: some View {
        Button(action: {
            if state.isOn {
                image = state.imageOff
                button.isOn = false
                model.updateButtonStates()
                actionOff()
            } else {
                image = state.imageOn
                button.isOn = true
                model.updateButtonStates()
                actionOn()
            }
        }, label: {
            ButtonImage(image: image, on: state.isOn)
        })
    }
}

struct ButtonsView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack {
            ForEach(model.buttonStates) { stateRow in
                HStack {
                    if let second = stateRow.second {
                        let button = model.enabledButtons[second.buttonIndex]
                        switch button.type {
                        case "Torch":
                             ButtonView(model: model, state: second, button: button)
                        case "Mute":
                             ButtonView(model: model, state: second, button: button)
                        case "Widget":
                             ButtonView(model: model, state: second, button: button)
                        default:
                            EmptyView()
                        }
                    } else {
                        ButtonPlaceholderImage()
                    }
                    let button = model.enabledButtons[stateRow.first.buttonIndex]
                    switch button.type {
                    case "Torch":
                         ButtonView(model: model, state: stateRow.first, button: button)
                    case "Mute":
                         ButtonView(model: model, state: stateRow.first, button: button)
                    case "Widget":
                         ButtonView(model: model, state: stateRow.first, button: button)
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}
