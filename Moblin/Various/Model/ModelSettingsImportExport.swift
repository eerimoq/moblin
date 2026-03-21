import UIKit

extension Model {
    func importFromFile(url: URL, completion: @escaping () -> Void) {
        settings.importFromFile(url: url) { message in
            if let message {
                self.failed(message: message)
            } else {
                self.succeeded()
            }
            completion()
        }
    }

    func importFromClipboard(completion: @escaping () -> Void) {
        guard let url = UIPasteboard.general.url ?? UIPasteboard.general.string
            .flatMap({ URL(string: $0) })
        else {
            failed(message: String(localized: "No URL found in clipboard"))
            completion()
            return
        }
        if url.scheme == "moblin" {
            if let message = handleSettingsUrl(url: url) {
                failed(message: message)
            } else {
                succeeded()
            }
            completion()
        } else {
            importFromFile(url: url, completion: completion)
        }
    }

    private func succeeded() {
        setCurrentStream()
        updateIconImageFromDatabase()
        reloadStream()
        resetSelectedScene()
        updateQuickButtonStates()
    }

    private func failed(message: String) {
        makeErrorToast(
            title: String(localized: "Import settings failed"),
            subTitle: message
        )
    }
}
