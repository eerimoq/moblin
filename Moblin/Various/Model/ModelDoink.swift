import Foundation

extension Model {
    func doinkLogin(stream: SettingsStream,
                    onComplete: (() -> Void)? = nil,
                    showWebBrowser: @escaping () -> Void)
    {
        doinkAuthOnComplete = { accessToken in
            storeDoinkAccessTokenInKeychain(streamId: stream.id, accessToken: accessToken)
            stream.doinkAccessToken = accessToken
            self.showDoinkAuth = false
            self.createStreamWizard.showDoinkAuth = false
            onComplete?()
        }
        doinkAuth.login(showWebBrowser: showWebBrowser)
    }

    func doinkLogout(stream: SettingsStream) {
        stream.doinkAccessToken = ""
        removeDoinkAccessTokenInKeychain(streamId: stream.id)
    }

    func handleDoinkAccessToken(accessToken: String) {
        doinkAuthOnComplete?(accessToken)
    }
}
