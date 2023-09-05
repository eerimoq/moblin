//
//  ImagePickerView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-05.
//

import SwiftUI

var imageSystemNames = ["mic",
                        "mic.fill",
                        "mic.slash",
                        "mic.slash.fill",
                        "film.fill",
                        "film",
                        "popcorn.fill",
                        "popcorn",
                        "gift",
                        "gift.fill",
                        "trash",
                        "trash.fill",
                        "paperplane",
                        "paperplane.fill",
                        "externaldrive.fill",
                        "externaldrive",
                        "arrowshape.right.fill",
                        "arrowshape.left",
                        "arrowshape.left.fill",
                        "arrowshape.right",
                        "figure.stand",
                        "figure.2.arms.open",
                        "figure.walk",
                        "figure.wave",
                        "tennis.racket",
                        "trophy.fill",
                        "trophy",
                        "peacesign",
                        "globe",
                        "globe.americas",
                        "globe.europe.africa",
                        "globe.asia.australia.fill",
                        "globe.central.south.asia",
                        "globe.central.south.asia.fill",
                        "sun.min.fill",
                        "globe.americas.fill",
                        "globe.europe.africa.fill",
                        "globe.asia.australia",
                        "sun.min",
                        "tornado",
                        "flashlight.on.fill",
                        "flashlight.off.fill",
                        "lightbulb",
                        "lightbulb.fill"]

struct ButtonImagePickerSettingsView: View {
    var title: String
    @State var value: String
    var onChange: (String) -> Void

    var body: some View {
        Form {
            Picker("", selection: $value) {
                ForEach(imageSystemNames, id: \.self) { imageSystemName in
                    HStack {
                        Image(systemName: imageSystemName)
                        Text(imageSystemName).foregroundColor(.gray)
                    }
                }
            }
            .onChange(of: value) { image in
                onChange(image)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .navigationTitle(title)
    }
}
