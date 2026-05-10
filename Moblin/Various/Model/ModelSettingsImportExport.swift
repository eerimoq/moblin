import UIKit
import UniformTypeIdentifiers

extension Model {
    func importSettingsWithConfirmation(action: @escaping () -> Void) {
        pendingSettingsImportAction = action
        presentingSettingsImportConfirmation = true
    }

    func importSettingsFromFile(url: URL, completion: @escaping @MainActor () -> Void) {
        settings.importFromFile(url: url) {
            self.importDone(message: $0)
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func importSettingsFromClipboard(completion: @escaping @MainActor () -> Void) {
        let typeIdentifier = moblinSettingsFileType.identifier
        if let provider = UIPasteboard.general.itemProviders
            .first(where: { $0.hasItemConformingToTypeIdentifier(typeIdentifier) })
        {
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { settings, _ in
                DispatchQueue.main.async {
                    guard let settings else {
                        self.importFailed(message: String(localized: "No settings found in clipboard"))
                        completion()
                        return
                    }
                    let settingsUrl = FileManager.default.temporaryDirectory
                        .appendingPathComponent("clipboard_import")
                        .appendingPathExtension("moblinSettings")
                    try? settings.write(to: settingsUrl)
                    self.importSettingsFromFile(url: settingsUrl) {
                        try? FileManager.default.removeItem(at: settingsUrl)
                        completion()
                    }
                }
            }
        } else if let settings = UIPasteboard.general.string {
            self.settings.importFromClipboard(settings: settings) {
                self.importDone(message: $0)
                DispatchQueue.main.async {
                    completion()
                }
            }
        } else {
            importFailed(message: String(localized: "No settings found in clipboard"))
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    func exportToFile(completion: @escaping @MainActor (URL?) -> Void) {
        settings.exportToFile(onCompleted: completion)
    }

    private func importDone(message: String?) {
        if let message {
            importFailed(message: message)
        } else {
            importSucceeded()
        }
    }

    private func importSucceeded() {
        setCurrentStream()
        updateIconImageFromDatabase()
        reloadStream()
        resetSelectedScene()
        updateQuickButtonStates()
        makeToast(title: String(localized: "Settings imported"))
    }

    private func importFailed(message: String) {
        makeErrorToast(title: String(localized: "Import settings failed"), subTitle: message)
    }
}
