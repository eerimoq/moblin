import UIKit
import UniformTypeIdentifiers

extension Model {
    func importFromFile(url: URL, completion: @escaping () -> Void) {
        settings.importFromFile(url: url) {
            self.done(message: $0)
            completion()
        }
    }

    func importFromClipboard(completion: @escaping () -> Void) {
        if let data = UIPasteboard.general.string {
            settings.importFromClipboard(settings: data) {
                self.done(message: $0)
                completion()
            }
            return
        }
        let typeIdentifier = UTType.moblinSettings.identifier
        for provider in UIPasteboard.general.itemProviders
            where provider.hasItemConformingToTypeIdentifier(typeIdentifier)
        {
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                DispatchQueue.main.async {
                    self.handleClipboardData(data: data, completion: completion)
                }
            }
            return
        }
        failed(message: String(localized: "No settings found in clipboard"))
        completion()
    }

    func importSettingsWithConfirmation(action: @escaping () -> Void) {
        pendingSettingsImportAction = action
        presentingSettingsImportConfirmation = true
    }

    private func handleClipboardData(data: Data?, completion: @escaping () -> Void) {
        guard let data else {
            failed(message: String(localized: "Failed to read clipboard data"))
            completion()
            return
        }
        let tempUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipboard_import")
            .appendingPathExtension("moblinSettings")
        do {
            try data.write(to: tempUrl)
        } catch {
            failed(message: String(localized: "Failed to save clipboard data"))
            completion()
            return
        }
        importFromFile(url: tempUrl) {
            try? FileManager.default.removeItem(at: tempUrl)
            completion()
        }
    }

    private func done(message: String?) {
        if let message {
            failed(message: message)
        } else {
            succeeded()
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
