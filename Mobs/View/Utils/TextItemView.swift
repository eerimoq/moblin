//
//  TextItemView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct TextItemView: View {
    var name: String
    var value: String
    var sensitive: Bool = false
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text(replaceSensitive(value: value, sensitive: sensitive)).foregroundColor(.gray)
        }
    }
}
