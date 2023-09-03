//
//  ButtonsSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-03.
//

import SwiftUI

struct ButtonsSettingsView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        Text("Add configuration of buttons here!")
    }
}

struct ButtonsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonsSettingsView(model: Model())
    }
}
