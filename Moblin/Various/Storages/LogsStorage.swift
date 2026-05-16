import Collections
import Foundation

private let maximumNumberOfLogFiles = 10
private let maximumLogFileSizeBytes: UInt64 = 10 * 1024 * 1024

class LogsStorage {
    private let fileManager: FileManager
    private var logsUrl: URL
    private var currentFileHandle: FileHandle?
    private var currentFileUrl: URL?
    private var currentFileSize: UInt64 = 0

    init() {
        fileManager = FileManager.default
        logsUrl = createAndGetDirectory(name: "Logs")
    }

    deinit {
        closeCurrentFile()
    }

    func write(lines: [String]) {
        guard !lines.isEmpty else {
            return
        }
        let blob = (lines.joined(separator: "\n") + "\n").utf8Data
        let blobSize = UInt64(blob.count)
        if currentFileHandle == nil {
            let files = logFiles()
            if let latestFile = files.last,
               latestFile.fileSize + blobSize < maximumLogFileSizeBytes
            {
                setCurrentFile(url: latestFile)
            }
            if currentFileHandle == nil {
                openNewFile()
            }
        } else if currentFileSize + blobSize >= maximumLogFileSizeBytes {
            openNewFile()
        }
        guard let currentFileHandle else {
            return
        }
        currentFileHandle.write(blob)
        currentFileSize += blobSize
    }

    func flush() {
        try? currentFileHandle?.synchronize()
    }

    private func logFiles() -> [URL] {
        let urls = (try? fileManager.contentsOfDirectory(
            at: logsUrl,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        var logUrls: [URL] = []
        for url in urls {
            if url.pathComponents.last?.starts(with: "Log_") == true {
                logUrls.append(url)
            } else {
                try? fileManager.removeItem(at: url)
            }
        }
        return logUrls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func openNewFile() {
        closeCurrentFile()
        var files = logFiles()
        let newFileUrl = logsUrl.appendingPathComponent("Log_\(formatFilenameDateAndTime()).txt")
        while files.count >= maximumNumberOfLogFiles {
            try? fileManager.removeItem(at: files.removeFirst())
        }
        fileManager.createFile(atPath: newFileUrl.path, contents: nil)
        setCurrentFile(url: newFileUrl)
    }

    private func setCurrentFile(url: URL) {
        currentFileHandle = try? FileHandle(forWritingTo: url)
        _ = try? currentFileHandle?.seekToEnd()
        currentFileUrl = url
        currentFileSize = url.fileSize
    }

    private func closeCurrentFile() {
        try? currentFileHandle?.close()
        currentFileHandle = nil
        currentFileUrl = nil
        currentFileSize = 0
    }
}
