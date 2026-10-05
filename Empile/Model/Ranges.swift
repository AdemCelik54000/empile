extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension ClosedRange where Bound: FloatingPoint {
    /// The value `fraction` of the way from the lower to the upper bound (0 = lower, 1 = upper).
    func value(at fraction: Bound) -> Bound {
        lowerBound + (upperBound - lowerBound) * fraction.clamped(to: 0...1)
    }
}
