import Foundation

struct FeatureVideo: Identifiable {
    let id: String
    let thumbnail: String

    static let soundBoard = FeatureVideo(id: "qJaUdIUuIhM", thumbnail: "FeatureVideoSoundBoard")
    static let webcamInObs = FeatureVideo(id: "_4ISwYTKV3s", thumbnail: "FeatureVideoWebcamInObs")
    static let chatSnapshotsToDiscord = FeatureVideo(
        id: "MHUT8al6Wg8",
        thumbnail: "FeatureVideoChatSnapshotsToDiscord"
    )
    static let twitchRaid = FeatureVideo(id: "r-60-f4prss", thumbnail: "FeatureVideoTwitchRaid")
    static let zoomAndSceneControls = FeatureVideo(
        id: "5v07BwaDe0s",
        thumbnail: "FeatureVideoZoomAndSceneControls"
    )
    static let findQuickButtons = FeatureVideo(
        id: "QWYT2eC-cio",
        thumbnail: "FeatureVideoFindQuickButtons"
    )
    static let all: [FeatureVideo] = [
        .findQuickButtons,
        .webcamInObs,
        .chatSnapshotsToDiscord,
        .soundBoard,
        .twitchRaid,
        .zoomAndSceneControls,
    ]

    func url() -> URL {
        URL(string: "https://www.youtube.com/shorts/\(id)")!
    }
}
