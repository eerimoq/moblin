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

struct ControlBarView_Previews: PreviewProvider {
    static var previews: some View {
        ControlBarView(model: Model())
    }
}
