//
//  TextEditView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-03.
//

import SwiftUI

struct TextEditView: View {
    var title: String
    @State var value: String
    var onSubmit: (String) -> Void

    var body: some View {
        Form {
            TextField("", text: $value)
                .onSubmit {
                    onSubmit(value.trim())
                }
        }
        .navigationTitle(title)
    }
}
