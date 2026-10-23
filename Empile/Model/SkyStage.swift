/// Which sky to show for a score: the first one until the first step, then a new one at every step,
/// cycling through the others once they have all been seen.
enum SkyStage {
    static func index(forScore score: Int, step: Int, count: Int) -> Int {
        guard step > 0, count > 1, score >= step else { return 0 }
        return 1 + (score / step - 1) % (count - 1)
    }
}
