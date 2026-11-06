import Foundation
import SwiftUI

struct RemoteControlTallyLeases {
    private var deadlines: [UUID: Double] = [:]

    var on: Bool {
        !deadlines.isEmpty
    }

    var nextExpiry: Double? {
        deadlines.values.min()
    }

    mutating func set(on: Bool, sourceId: UUID, now: Double) {
        expire(now: now)
        if on {
            deadlines[sourceId] = now + 10
        } else {
            deadlines.removeValue(forKey: sourceId)
        }
    }

    mutating func expire(now: Double) {
        deadlines = deadlines.filter { $0.value > now }
    }
}

@MainActor
class RemoteControlTally: ObservableObject {
    @Published private(set) var on = false
    private var leases = RemoteControlTallyLeases()
    private let timer = MainTimer()
    private let reference = ContinuousClock.now

    private func now() -> Double {
        let elapsed = reference.duration(to: .now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }

    func set(on: Bool, sourceId: UUID) {
        leases.set(on: on, sourceId: sourceId, now: now())
        update()
    }

    private func expire() {
        leases.expire(now: now())
        update()
    }

    private func update() {
        if on != leases.on {
            on = leases.on
        }
        if let deadline = leases.nextExpiry {
            timer.startSingleShot(timeout: max(deadline - now(), 0)) { [weak self] in
                self?.expire()
            }
        } else {
            timer.stop()
        }
    }
}
