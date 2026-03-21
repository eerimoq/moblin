import Foundation

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
        settings.importFromClipboard { message in
            if let message {
                self.failed(message: message)
            } else {
                self.succeeded()
            }
            completion()
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
