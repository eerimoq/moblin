import SwiftUI

struct StreamVideoBitrateSettingsView: View {
    @ObservedObject var model: Model
    var stream: SettingsStream

    func onSubmit(value: String) {
        if let value = UInt32(value) {
            stream.bitrate = value
            model.store()
            if stream.enabled {
                model.setStreamBitrate()
            }
        }
    }
    
    var body: some View {
        TextEditView(title: "Bitrate", value: String(stream.bitrate), onSubmit: onSubmit)
    }
}
