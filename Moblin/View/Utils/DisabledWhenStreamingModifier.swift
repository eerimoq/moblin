import SwiftUI

extension View {
    func disabledWhenLiveStreaming(stream: SettingsStream, model: Model) -> some View {
        disabled(stream.enabled && model.isLive)
    }

    func disabledWhenLiveStreamingOrRecording(stream: SettingsStream, model: Model) -> some View {
        disabled(stream.enabled && (model.isLive || model.isRecording))
    }
}
