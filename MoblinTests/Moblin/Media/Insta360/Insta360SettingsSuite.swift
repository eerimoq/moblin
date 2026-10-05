import Foundation
@testable import Moblin
import Testing

struct Insta360SettingsSuite {
    @Test
    func olderSettingsDoNotStartACameraConnection() throws {
        let database = try JSONDecoder().decode(Database.self, from: Data("{}".utf8))
        #expect(!database.insta360.enabled)
        #expect(database.insta360.host == "192.168.42.1")
        #expect(database.insta360.latency == 300)
    }

    @Test
    func cameraAndSceneSelectionSurviveSavingAndReloading() throws {
        let database = Database()
        database.insta360.enabled = true
        database.insta360.host = "192.168.42.2"
        database.insta360.latency = 500
        let scene = SettingsScene(name: "GO Ultra")
        scene.videoSource.updateCameraId(settingsCameraId: .insta360(id: database.insta360.id))
        database.scenes = [scene]
        let data = try JSONEncoder().encode(database)
        let restored = try JSONDecoder().decode(Database.self, from: data)
        #expect(restored.insta360.id == database.insta360.id)
        #expect(restored.insta360.enabled)
        #expect(restored.insta360.host == "192.168.42.2")
        #expect(restored.insta360.latency == 500)
        let restoredScene = try #require(restored.scenes.first)
        #expect(restoredScene.videoSource.cameraPosition == .insta360)
        #expect(restoredScene.videoSource.isNetwork(cameraId: restored.insta360.id))
        #expect(restoredScene.clone().videoSource.insta360CameraId == restored.insta360.id)
    }
}
