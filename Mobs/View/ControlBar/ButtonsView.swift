//
//  ButtonsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-31.
//

import SwiftUI

struct ButtonImage: View {
    var image: String
    var on: Bool
    
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

struct ButtonsView: View {
    @ObservedObject var model: Model
    
    func getImage(button: SettingsButton, on: Bool) -> String {
        if on {
            return button.systemImageNameOn
        } else {
            return button.systemImageNameOff
        }
    }
    
    func torchAction(state: ButtonState) {
        state.button.isOn = !state.button.isOn
        model.toggleTorch()
        model.updateButtonStates()
    }
    
    func muteAction(state: ButtonState) {
        state.button.isOn = !state.button.isOn
        model.toggleMute()
        model.updateButtonStates()
    }
    
    func widgetAction(state: ButtonState) {
        state.button.isOn = !state.button.isOn
        if state.isOn {
            model.movieEffectOn()
        } else {
            model.movieEffectOff()
        }
        model.updateButtonStates()
    }
    
    var body: some View {
        VStack {
            ForEach(model.buttonStates) { stateRow in
                HStack {
                    if var second = stateRow.second {
                        switch second.button.type {
                        case "Torch":
                            Button(action: {
                                torchAction(state: second)
                            }, label: {
                                ButtonImage(image: getImage(button: second.button, on: second.isOn), on: second.isOn)
                            })
                        case "Mute":
                            Button(action: {
                                muteAction(state: second)
                            }, label: {
                                ButtonImage(image: getImage(button: second.button, on: second.isOn), on: second.isOn)
                            })
                        case "Widget":
                            Button(action: {
                                widgetAction(state: second)
                            }, label: {
                                ButtonImage(image: getImage(button: second.button, on: second.isOn), on: second.isOn)
                            })
                        default:
                            EmptyView()
                        }
                    } else {
                        ButtonPlaceholderImage()
                    }
                    switch stateRow.first.button.type {
                    case "Torch":
                        Button(action: {
                            torchAction(state: stateRow.first)
                        }, label: {
                            ButtonImage(image: getImage(button: stateRow.first.button, on: stateRow.first.isOn), on: stateRow.first.isOn)
                        })
                    case "Mute":
                        Button(action: {
                            muteAction(state: stateRow.first)
                        }, label: {
                            ButtonImage(image: getImage(button: stateRow.first.button, on: stateRow.first.isOn), on: stateRow.first.isOn)
                        })
                    case "Widget":
                        Button(action: {
                            widgetAction(state: stateRow.first)
                        }, label: {
                            ButtonImage(image: getImage(button: stateRow.first.button, on: stateRow.first.isOn), on: stateRow.first.isOn)
                        })
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}
