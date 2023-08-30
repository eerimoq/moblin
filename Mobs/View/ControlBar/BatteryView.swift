//
//  BatteryView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-08-30.
//

import SwiftUI

struct BatteryView: View {
    var level: Float
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .frame(width: 22, height: 12)
            Rectangle()
                .fill(Color(red: 88/255, green: 191/255, blue: 108/255))
                .frame(width: 22 * CGFloat(level >= 0 ? level : 0), height: 12)
        }
        .cornerRadius(3)
    }
}

struct BatteryView_Previews: PreviewProvider {
    static var previews: some View {
        BatteryView(level: 0.5)
    }
}
