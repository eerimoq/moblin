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
    @State private var isPresentingGoLiveConfirm: Bool = false
    @State private var isPresentingStopConfirm: Bool = false

    var body: some View {
        switch model.liveState {
        case .stopped:
            Button(action: {
                isPresentingGoLiveConfirm = true
            }, label: {
                StreamButtonText(text: "Go Live")
            })
            .disabled(model.stream == nil)
            .confirmationDialog("", isPresented: $isPresentingGoLiveConfirm) {
                Button("Go live") {
                    model.startStream()
                }
            }
        case .live:
            Button(action: {
                isPresentingStopConfirm = true
            }, label: {
                StreamButtonText(text: "Stop")
            })
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white)
            )
            .confirmationDialog("", isPresented: $isPresentingStopConfirm) {
                Button("Stop") {
                    model.stopStream()
                 }
            }
        }
    }
}

struct ControlBarView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    BatteryView(level: model.batteryLevel)
                    Spacer()
                    ThermalStateView(thermalState: model.thermalState)
                    Spacer()
                    Text(model.currentTime)
                        .font(.system(size: 13))
                }
                HStack {
                    Image("AppIconNoBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding([.bottom], 5)
                        .frame(width: 40, height: 40)
                    Button(action: {
                        logger.error("Settings")
                    }, label: {
                        NavigationLink(destination: SettingsView(model: model)) {
                            Image(systemName: "gearshape")
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(.secondary)
                                )
                        }
                    })
                }
                Spacer()
                ButtonsView(model: model)
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
