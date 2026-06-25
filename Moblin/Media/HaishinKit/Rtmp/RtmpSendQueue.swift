import DequeModule
import Foundation

enum RtmpChunkPriority: Int, Comparable {
    case control = 0
    case audio = 1
    case videoKeyframe = 2
    case videoInterframe = 3
    case metadata = 4

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

class RtmpSendQueue {
    // Index matches RtmpChunkPriority.rawValue
    // 0: control, 1: audio, 2: videoKeyframe, 3: videoInterframe, 4: metadata
    private var queues: Atomic<[Deque<Data>]> = .init(Array(repeating: Deque<Data>(), count: 5))

    func enqueue(_ data: Data, priority: RtmpChunkPriority) {
        queues.mutate { q in
            q[priority.rawValue].append(data)
        }
    }

    func dequeue() -> Data? {
        var data: Data?
        queues.mutate { q in
            for i in 0 ..< 5 where !q[i].isEmpty {
                data = q[i].removeFirst()
                break
            }
        }
        return data
    }

    func dropInterframes() {
        queues.mutate { q in
            q[RtmpChunkPriority.videoInterframe.rawValue].removeAll()
        }
    }

    func clear() {
        queues.mutate { q in
            for i in 0 ..< 5 {
                q[i].removeAll()
            }
        }
    }
}
