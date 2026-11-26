import Foundation

struct FeatureVideo: Identifiable {
    let id: String

    static let soundBoard = FeatureVideo(id: "qJaUdIUuIhM")
    static let webcamInObs = FeatureVideo(id: "_4ISwYTKV3s")
    static let chatSnapshotsToDiscord = FeatureVideo(id: "MHUT8al6Wg8")
    static let twitchRaid = FeatureVideo(id: "r-60-f4prss")
    static let zoomAndSceneControls = FeatureVideo(id: "5v07BwaDe0s")
    static let all: [FeatureVideo] = [
        .soundBoard,
        .webcamInObs,
        .chatSnapshotsToDiscord,
        .twitchRaid,
        .zoomAndSceneControls,
    ]

    func url() -> URL {
        URL(string: "https://www.youtube.com/shorts/\(id)")!
    }

    func thumbnailUrl() -> URL {
        URL(string: "https://i.ytimg.com/vi/\(id)/hq720.jpg")!
    }
}
