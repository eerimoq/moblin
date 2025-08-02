struct BufferedStats {
    private static let outputInterval = 5.0
    private var numberOfDuplicated = 0
    private var numberOfDropped = 0
    private var latestPresentationTimeStamp = 0.0

    mutating func incrementDuplicated() {
        numberOfDuplicated += 1
    }

    mutating func incrementDropped(count: Int) {
        numberOfDropped += count
    }

    mutating func getStats(_ presentationTimeStamp: Double) -> (Int, Int)? {
        guard presentationTimeStamp > latestPresentationTimeStamp + Self.outputInterval else {
            return nil
        }
        guard numberOfDuplicated > 0 || numberOfDropped > 0 else {
            return nil
        }
        defer {
            numberOfDuplicated = 0
            numberOfDropped = 0
        }
        latestPresentationTimeStamp = presentationTimeStamp
        return (numberOfDuplicated, numberOfDropped)
    }
}
