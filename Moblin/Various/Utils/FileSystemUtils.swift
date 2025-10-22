import Foundation

extension URL {
    var attributes: [FileAttributeKey: Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            logger.info("file-system: Failed to get attributes for file \(self)")
        }
        return nil
    }

    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }

    func remove() {
        try? FileManager.default.removeItem(at: self)
    }
}

extension FileManager {
    func ids(directory: String) -> [UUID] {
        var ids: [UUID] = []
        for file in (try? contentsOfDirectory(atPath: directory)) ?? [] {
            guard let id = UUID(uuidString: file) else {
                continue
            }
            ids.append(id)
        }
        return ids
    }

    func idsBeforeDot(directory: String) -> [UUID] {
        var ids: [UUID] = []
        for file in (try? contentsOfDirectory(atPath: directory)) ?? [] {
            let parts = file.components(separatedBy: ".")
            guard parts.count > 1, let id = UUID(uuidString: parts[0]) else {
                continue
            }
            ids.append(id)
        }
        return ids
    }
}

func getAvailableDiskSpace() -> UInt64? {
    guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: URL.homeDirectory.path()) else {
        return nil
    }
    return attributes[.systemFreeSize] as? UInt64
}

func deleteTrash() {
    let folders = [
        URL.temporaryDirectory,
        URL.documentsDirectory.appending(component: ".Trash"),
    ]
    for folder in folders {
        guard let paths = try? FileManager.default.contentsOfDirectory(atPath: folder.path()) else {
            continue
        }
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}

func createAndGetDirectory(name: String) -> URL {
    let directory = URL.documentsDirectory.appending(component: name)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
