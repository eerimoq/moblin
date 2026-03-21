import UIKit
import UniformTypeIdentifiers

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
        if let url = UIPasteboard.general.url {
            importFromClipboardUrl(url: url, completion: completion)
            return
        }
        if let string = UIPasteboard.general.string, let url = URL(string: string) {
            importFromClipboardUrl(url: url, completion: completion)
            return
        }
        importFromClipboardItemProviders(completion: completion)
    }

    private func importFromClipboardUrl(url: URL, completion: @escaping () -> Void) {
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

    private func importFromClipboardItemProviders(completion: @escaping () -> Void) {
        let typeIdentifiers = [
            UTType.moblinSettings.identifier,
            UTType.zip.identifier,
            UTType.data.identifier,
        ]
        for provider in UIPasteboard.general.itemProviders {
            for typeIdentifier in typeIdentifiers {
                if provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                        DispatchQueue.main.async {
                            self.handleClipboardData(data: data, completion: completion)
                        }
                    }
                    return
                }
            }
        }
        failed(message: String(localized: "No settings found in clipboard"))
        completion()
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
