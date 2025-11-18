func isEqual<T: FloatingPoint>(_ actual: T, _ expected: T, epsilon: T) -> Bool {
    return abs(actual - expected) < epsilon
}
