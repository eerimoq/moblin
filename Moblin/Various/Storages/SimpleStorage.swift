import Foundation

private func setup() -> URL {
    let url = URL.libraryDirectory.appending(component: "SimpleStorage")
    do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let testFile = url.appending(component: ".init")
        try Data().write(to: testFile)
        try? FileManager.default.removeItem(at: testFile)
    } catch {
        exit(EXIT_SUCCESS)
    }
    return url
}

private let directory = setup()

final class SimpleStringStorage {
    private let file: URL

    init(key: String) {
        file = directory.appending(component: key)
        if !file.exists() {
            set(UserDefaults.standard.string(forKey: key) ?? "")
        }
    }

    func get() -> String {
        file.readString()
    }

    func set(_ value: String) {
        file.writeString(value)
    }
}

final class SimpleIntStorage {
    private let file: URL

    init(key: String) {
        file = directory.appending(component: key)
        if !file.exists() {
            set(UserDefaults.standard.integer(forKey: key))
        }
    }

    func get() -> Int {
        if let value = Int(file.readString()) {
            value
        } else {
            exit(EXIT_SUCCESS)
        }
    }

    func set(_ value: Int) {
        file.writeString(String(value))
    }
}

private extension URL {
    func writeString(_ value: String) {
        do {
            try value.write(to: self, atomically: true, encoding: .utf8)
        } catch {
            exit(EXIT_SUCCESS)
        }
    }

    func readString() -> String {
        do {
            return try String(contentsOf: self, encoding: .utf8)
        } catch {
            exit(EXIT_SUCCESS)
        }
    }
}
