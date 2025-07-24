import Foundation

extension Model {
    func updateDisconnectProtection() {
        guard let fallbackSceneId = database.disconnectProtection.fallbackSceneId,
              selectedSceneId == fallbackSceneId,
              let liveSceneId = database.disconnectProtection.liveSceneId
        else {
            return
        }
        guard isSceneVideoSourceActive(sceneId: liveSceneId) else {
            return
        }
        selectScene(id: liveSceneId)
    }

    func updateDisconnectProtectionVideoSourceDisconnected() {
        guard !isSceneVideoSourceActive(sceneId: selectedSceneId) else {
            return
        }
        guard let liveSceneId = database.disconnectProtection.liveSceneId,
              selectedSceneId == liveSceneId,
              let fallbackSceneId = database.disconnectProtection.fallbackSceneId
        else {
            return
        }
        selectScene(id: fallbackSceneId)
    }
}
