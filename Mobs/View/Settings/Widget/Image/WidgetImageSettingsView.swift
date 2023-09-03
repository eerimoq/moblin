//
//  WidgetImageSettingsView.swift
//  Mobs
//
//  Created by Erik Moqvist on 2023-09-02.
//

import SwiftUI

struct PickView: View {
    @State var image = UIImage()

    var body: some View {
        ImagePickerView(sourceType: .photoLibrary, selectedImage: $image)
            .navigationTitle("File")
    }
}   

struct WidgetImageSettingsView: View {
    @ObservedObject var model: Model
    var widget: SettingsWidget
    
    func submitUrl(value: String) {
        widget.image.url = value
        model.store()
    }
    
    var body: some View {
        Section(widget.type) {
            NavigationLink(destination: TextEditView(title: "URL", value: widget.image.url, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: widget.image.url)
            //NavigationLink(destination: PickView()) {
            //   TextItemView(name: "File", value: widget.image.url)
            }
        }
    }
}
