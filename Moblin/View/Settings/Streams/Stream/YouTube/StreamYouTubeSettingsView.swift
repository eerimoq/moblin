import SwiftUI

struct StreamYouTubeSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var stream: SettingsStream

    func submitVideoId(value: String) {
        stream.youTubeVideoId = value
        if stream.enabled {
            model.youTubeVideoIdUpdated()
        }
    }

    func submitHandle(value: String) {
        stream.youTubeHandle = value
    }

    var body: some View {
        Form {
            Section {
                TextEditBindingNavigationView(
                    title: String(localized: "Channel handle"),
                    value: $stream.youTubeHandle,
                    onSubmit: submitHandle,
                    placeholder: "@erimo144"
                )
                TextEditBindingNavigationView(
                    title: String(localized: "Video id"),
                    value: $stream.youTubeVideoId,
                    onSubmit: submitVideoId,
                    placeholder: "FekKCUN5W8U"
                )
                HCenter {
                    Button {
                        Task {
                            do {
                                let videoId = try await fetchYouTubeVideoId(handle: stream.youTubeHandle)
                                submitVideoId(value: videoId)
                            } catch {
                                model.makeErrorToast(title: String(localized: "Failed to fetch YouTube Video ID"),
                                                     subTitle: String(
                                                         localized: "You must be live on YouTube for this to work."
                                                     ))
                            }
                        }
                    } label: {
                        Text("Fetch Video ID")
                    }
                }
            } footer: {
                Text("The Video ID unique for every live stream.")
            }
        }
        .navigationTitle("YouTube")
    }
}
