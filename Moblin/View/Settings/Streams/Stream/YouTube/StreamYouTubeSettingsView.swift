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
                TextEditNavigationView(
                    title: String(localized: "Channel handle"),
                    value: String(stream.youTubeHandle),
                    onSubmit: submitHandle,
                    placeholder: "@erimo144"
                )
                TextEditNavigationView(
                    title: String(localized: "Video id"),
                    value: String(stream.youTubeVideoId),
                    onSubmit: submitVideoId,
                    placeholder: "FekKCUN5W8U"
                )
                TextButtonView("Fetch Video ID") {
                    Task { @MainActor in
                        do {
                            let videoId = try await fetchYouTubeVideoId(handle: stream.youTubeHandle)
                            submitVideoId(value: videoId)
                        } catch {
                            model.makeErrorToast(
                                title: String(localized: "Failed to fetch YouTube Video ID"),
                                subTitle: String(localized: "You must be live on YouTube for this to work.")
                            )
                        }
                    }
                }
            } footer: {
                Text("The Video ID unique for every live stream.")
            }
        }
        .navigationTitle("YouTube")
    }
}
