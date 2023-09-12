import SwiftUI

struct StreamSrtSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream
    
    func submitUrl(value: String) {
        if URL(string: value) == nil {
            return
        }
        stream.srtUrl = value
        model.store()
        if stream.enabled {
            model.srtUrlChanged()
        }
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: SensitiveUrlEditView(value: stream.srtUrl, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: stream.srtUrl, sensitive: true)
            }
            Toggle("SRTLA", isOn: Binding(get: {
                stream.srtla
            }, set: { value in
                stream.srtla = value
                model.store()
                if stream.enabled {
                    model.srtlaChanged()
                }
            }))
        }
        .navigationTitle("SRT")
    }
}
