import Foundation

extension Model {
    func updateDisconnectProtectionVideoSourceConnected() {
        guard let fallbackSceneId = database.disconnectProtection.fallbackSceneId,
              sceneSelector.selectedSceneId == fallbackSceneId,
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
        guard !isSceneVideoSourceActive(sceneId: sceneSelector.selectedSceneId) else {
            return
        }
        guard let liveSceneId = database.disconnectProtection.liveSceneId,
              sceneSelector.selectedSceneId == liveSceneId,
              let fallbackSceneId = database.disconnectProtection.fallbackSceneId
        else {
            return
        }
        selectScene(id: fallbackSceneId)
    }
}
