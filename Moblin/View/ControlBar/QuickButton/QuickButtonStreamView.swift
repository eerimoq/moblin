import Foundation
import SwiftUI

private struct StreamSwitcherView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Picker("", selection: $model.currentStreamId) {
                    ForEach(model.database.streams) { stream in
                        Text(stream.name)
                    }
                }
                .onChange(of: model.currentStreamId) { _ in
                    model.stopStream()
                    model.stopRecording()
                    if model.setCurrentStream(streamId: model.currentStreamId) {
                        model.reloadStream()
                        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                        model.setIsLive(value: true)
                        DispatchQueue.main
                            .asyncAfter(deadline: .now() + 3) {
                                model.startStream(delayed: true)
                            }
                    } else {
                        model.makeErrorToast(title: "Failed to switch stream")
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("Automatically goes live when switching stream.")
            }
        }
        .navigationTitle("Stream switcher")
    }
}

private struct StreamConnectionPrioritiesView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        StreamSrtConnectionPriorityView(stream: model.stream)
    }
}

struct QuickButtonStreamView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    QuickButtonBitrateView(selection: model.stream.bitrate)
                } label: {
                    Text("Bitrate")
                }
                if model.stream.getProtocol() == .srt {
                    NavigationLink {
                        StreamConnectionPrioritiesView()
                    } label: {
                        Text("Connection priorities")
                    }
                }
                NavigationLink {
                    StreamSwitcherView()
                } label: {
                    Text("Stream switcher")
                }
            }
        }
        .navigationTitle("Stream")
    }
}
