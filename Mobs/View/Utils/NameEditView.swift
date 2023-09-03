//
//  NameEditView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-03.
//

import SwiftUI

struct NameEditView: View {
    @State var name: String
    var onSubmit: (String) -> Void

    var body: some View {
        TextEditView(title: "Name", value: name, onSubmit: onSubmit)
    }
}
