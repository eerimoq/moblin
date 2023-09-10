import SwiftUI

struct StreamRtmpSettingsView: View {
    @ObservedObject private var model: Model
    private var stream: SettingsStream
    
    init(model: Model, stream: SettingsStream) {
        self.model = model
        self.stream = stream
    }
    
    func submitUrl(value: String) {
        if makeRtmpUri(url: value) == "" {
            return
        }
        if makeRtmpStreamName(url: value) == "" {
            return
        }
        stream.rtmpUrl = value
        model.store()
        if stream.enabled {
            model.rtmpUrlChanged()
        }
    }
    
    var body: some View {
        Form {
            NavigationLink(destination: SensitiveUrlEditView(value: stream.rtmpUrl, onSubmit: submitUrl)) {
                TextItemView(name: "URL", value: stream.rtmpUrl, sensitive: true)
            }
        }
        .navigationTitle("RTMP")
    }
}
