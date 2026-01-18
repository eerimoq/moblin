import Foundation

class Keychain {
    private let streamId: String
    private let server: String
    private let logPrefix: String

    init(streamId: String, server: String, logPrefix: String) {
        self.streamId = streamId
        self.server = server
        self.logPrefix = logPrefix
    }

    func store(value: String) {
        guard let valueData = value.data(using: .utf8) else {
            return
        }
        if !update(valueData: valueData) {
            add(valueData: valueData)
        }
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: streamId,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            return nil
        }
        guard status == errSecSuccess else {
            logger.info("\(logPrefix): Failed to query item to keychain")
            return nil
        }
        guard let existingItem = item as? [String: Any],
              let valueData = existingItem[kSecValueData as String] as? Data,
              let value = String(data: valueData, encoding: String.Encoding.utf8)
        else {
            logger.info("\(logPrefix): Failed to lookup attributes")
            return nil
        }
        return value
    }

    func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: streamId,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.info("\(logPrefix): Keychain delete failed")
            return
        }
    }

    private func update(valueData: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: streamId,
        ]
        let attributes: [String: Any] = [
            kSecAttrAccount as String: streamId,
            kSecValueData as String: valueData,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status != errSecItemNotFound else {
            return false
        }
        guard status == errSecSuccess else {
            logger.info("\(logPrefix): Failed to update item in keychain")
            return false
        }
        return true
    }

    private func add(valueData: Data) {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: streamId,
            kSecValueData as String: valueData,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.info("\(logPrefix): Failed to add item to keychain")
            return
        }
    }
}
