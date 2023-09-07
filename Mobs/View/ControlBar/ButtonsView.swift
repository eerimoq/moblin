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

struct GenericButton: View {
    @State private var image: String
    private var imageOn: String
    private var imageOff: String
    private var actionOn: () -> Void
    private var actionOff: () -> Void
    private var isOn: Binding<Bool>

    init(isOn: Binding<Bool>, imageOn: String, imageOff: String, actionOn: @escaping () -> Void, actionOff: @escaping () -> Void) {
        self.isOn = isOn
        self.imageOn = imageOn
        self.imageOff = imageOff
        self.actionOn = actionOn
        self.actionOff = actionOff
        self.image = imageOff
    }
    
    var body: some View {
        Button(action: {
            if isOn.wrappedValue {
                image = imageOff
                actionOff()
            } else {
                image = imageOn
                actionOn()
            }
        }, label: {
            ButtonImage(image: image, on: isOn.wrappedValue)
        })
    }
}

struct ButtonsView: View {
    @ObservedObject var model: Model
    
    init(model: Model) {
        self.model = model
    }
    
    func buildButton(index: Int) -> GenericButton {
        let button = model.enabledButtons[index]
        switch button.type {
        case "Torch":
            return GenericButton(isOn: $model.isTorchOn,
                                 imageOn: button.systemImageNameOn,
                                 imageOff: button.systemImageNameOff,
                                 actionOn: {
                                     model.toggleTorch()
                                 },
                                 actionOff: {
                                     model.toggleTorch()
                                 })
        case "Mute":
            return GenericButton(isOn: $model.isMuteOn,
                                 imageOn: button.systemImageNameOn,
                                 imageOff: button.systemImageNameOff,
                                 actionOn: {
                                     model.toggleMute()
                                 },
                                 actionOff: {
                                     model.toggleMute()
                                 })
        case "Widget":
            return GenericButton(isOn: $model.isMovieOn,
                                 imageOn: button.systemImageNameOn,
                                 imageOff: button.systemImageNameOff,
                                 actionOn: {
                                     model.movieEffectOn()
                                 },
                                 actionOff: {
                                     model.movieEffectOff()
                                 })
        default:
            fatalError("Should never be executed")
        }
    }
    
    var body: some View {
        VStack {
            ForEach(model.rowIndexes) { rowIndex in
                HStack {
                    let evenNumberOfColumns = ((rowIndex.id + 1) * 2 <= model.enabledButtons.count)
                    if evenNumberOfColumns {
                        buildButton(index: 2 * rowIndex.id + 1)
                    } else {
                        ButtonPlaceholderImage()
                    }
                    buildButton(index: 2 * rowIndex.id)
                }
            }
        }
    }
}
