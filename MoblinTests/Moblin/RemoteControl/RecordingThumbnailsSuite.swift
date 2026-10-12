import Foundation
@testable import Moblin
import Testing

@MainActor
private class RecordingThumbnailLoader {
    var completions: [@MainActor (Data?) -> Void] = []

    func load(url _: URL, onComplete: @escaping @MainActor (Data?) -> Void) {
        completions.append(onComplete)
    }
}

@MainActor
struct RecordingThumbnailsSuite {
    private let url = URL(fileURLWithPath: "/recording.mp4")

    @Test
    func coalescesRequestsAndCachesSuccess() throws {
        let loader = RecordingThumbnailLoader()
        defer { loader.completions.removeAll() }
        let thumbnails = RecordingThumbnails(load: loader.load)
        var results: [Data?] = []
        var urlRequests = 0
        let makeUrl = {
            urlRequests += 1
            return url
        }
        thumbnails.get(filename: "recording.mp4", url: makeUrl()) { results.append($0) }
        thumbnails.get(filename: "recording.mp4", url: makeUrl()) { results.append($0) }
        try #require(loader.completions.count == 1)
        #expect(urlRequests == 1)
        #expect(results.isEmpty)
        let thumbnail = Data([1, 2, 3])
        loader.completions[0](thumbnail)
        #expect(results == [thumbnail, thumbnail])
        thumbnails.get(filename: "recording.mp4", url: makeUrl()) { results.append($0) }
        #expect(loader.completions.count == 1)
        #expect(urlRequests == 1)
        #expect(results == [thumbnail, thumbnail, thumbnail])
        thumbnails.remove(filename: "recording.mp4")
        thumbnails.get(filename: "recording.mp4", url: url) { results.append($0) }
        try #require(loader.completions.count == 2)
        loader.completions[1](nil)
        #expect(results == [thumbnail, thumbnail, thumbnail, nil])
    }

    @Test
    func failureCompletesWaitersAndCanRetry() throws {
        let loader = RecordingThumbnailLoader()
        defer { loader.completions.removeAll() }
        let thumbnails = RecordingThumbnails(load: loader.load)
        var results: [Data?] = []
        thumbnails.get(filename: "recording.mp4", url: url) { results.append($0) }
        thumbnails.get(filename: "recording.mp4", url: url) { results.append($0) }
        try #require(loader.completions.count == 1)
        loader.completions[0](nil)
        #expect(results.count == 2)
        #expect(results.allSatisfy { $0 == nil })
        thumbnails.get(filename: "recording.mp4", url: url) { results.append($0) }
        try #require(loader.completions.count == 2)
        let thumbnail = Data([4, 5, 6])
        loader.completions[1](thumbnail)
        #expect(results == [nil, nil, thumbnail])
    }

    @Test
    func removalInvalidatesOldCompletionWithoutRemovingReplacement() throws {
        let loader = RecordingThumbnailLoader()
        defer { loader.completions.removeAll() }
        let thumbnails = RecordingThumbnails(load: loader.load)
        var oldResults: [Data?] = []
        var newResults: [Data?] = []
        thumbnails.get(filename: "recording.mp4", url: url) { oldResults.append($0) }
        thumbnails.get(filename: "recording.mp4", url: url) { oldResults.append($0) }
        thumbnails.remove(filename: "recording.mp4")
        #expect(oldResults.count == 2)
        #expect(oldResults.allSatisfy { $0 == nil })
        thumbnails.get(filename: "recording.mp4", url: url) { newResults.append($0) }
        try #require(loader.completions.count == 2)
        loader.completions[0](Data([1]))
        #expect(oldResults.count == 2)
        #expect(newResults.isEmpty)
        thumbnails.get(filename: "recording.mp4", url: url) { newResults.append($0) }
        #expect(loader.completions.count == 2)
        let thumbnail = Data([2])
        loader.completions[1](thumbnail)
        #expect(newResults == [thumbnail, thumbnail])
        thumbnails.get(filename: "recording.mp4", url: url) { newResults.append($0) }
        #expect(loader.completions.count == 2)
        #expect(newResults == [thumbnail, thumbnail, thumbnail])
    }

    @Test
    func differentFilenamesHaveIndependentRequests() throws {
        let loader = RecordingThumbnailLoader()
        defer { loader.completions.removeAll() }
        let thumbnails = RecordingThumbnails(load: loader.load)
        var results: [String: Data] = [:]
        thumbnails.get(filename: "first.mp4", url: url) { results["first"] = $0 }
        thumbnails.get(filename: "second.mp4", url: url) { results["second"] = $0 }
        try #require(loader.completions.count == 2)
        loader.completions[1](Data([2]))
        loader.completions[0](Data([1]))
        #expect(results == ["first": Data([1]), "second": Data([2])])
    }

    @Test(arguments: [false, true])
    func missingOrCorruptFileReturnsNil(createFile: Bool) async throws {
        let fileUrl = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        if createFile {
            try Data([1, 2, 3]).write(to: fileUrl)
        }
        defer { try? FileManager.default.removeItem(at: fileUrl) }
        let thumbnails = RecordingThumbnails()
        let thumbnail: Data? = await withCheckedContinuation { continuation in
            thumbnails.get(filename: fileUrl.lastPathComponent, url: fileUrl) { data in
                #expect(Thread.isMainThread)
                continuation.resume(returning: data)
            }
        }
        #expect(thumbnail == nil)
    }
}
