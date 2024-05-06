import Foundation

struct Histogram {
    let name: String
    let barWidth: Int
    private(set) var barCounts: [Int] = []

    init(name: String, barWidth: Int) {
        self.name = name
        self.barWidth = barWidth
    }

    mutating func add(value: Int) {
        let barIndex = max(value / barWidth, 0)
        while barIndex >= barCounts.count {
            barCounts.append(0)
        }
        barCounts[barIndex] += 1
    }

    func log() {
        logger.debug("histogram: \(name): \(barCounts)")
    }
}
