import Foundation

/// SplitMix64 — small, fast, and identical on every platform and Swift version.
///
/// Determinism matters here: the app, the widget extension and any exported
/// image must all agree on which word belongs to a given hour without talking
/// to each other.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform value in `0..<upperBound`, unbiased via rejection sampling.
    public mutating func next(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive")
        let bound = UInt64(upperBound)
        let limit = UInt64.max - (UInt64.max % bound)
        var value = next()
        while value >= limit { value = next() }
        return Int(value % bound)
    }

    /// Double in `0..<1`.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

extension Array {
    /// Fisher–Yates shuffle written out by hand so the ordering is stable
    /// across Swift releases (the stdlib's `shuffle(using:)` is not contractually).
    func deterministicallyShuffled(using generator: inout SeededGenerator) -> [Element] {
        var result = self
        guard result.count > 1 else { return result }
        for index in stride(from: result.count - 1, to: 0, by: -1) {
            let swapIndex = generator.next(upperBound: index + 1)
            result.swapAt(index, swapIndex)
        }
        return result
    }
}
