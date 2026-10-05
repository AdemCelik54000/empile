import CoreGraphics

/// A height milestone just reached, and the gems it gave.
struct Milestone: Equatable, Sendable {
    /// Height of the milestone, in floors.
    let floors: Int
    let gems: Int
}

/// How high the tower has climbed, and which milestones that earned.
struct ClimbProgress: Equatable, Sendable {
    /// Floors between two milestones.
    let milestoneFloors: Int
    let gemsPerMilestone: Int
    /// Current height of the still tower, in floors.
    private(set) var floors = 0
    /// Highest the tower has stood during this game.
    private(set) var bestFloors = 0

    /// Milestones reached so far: also the difficulty level.
    var milestonesReached: Int { milestoneFloors > 0 ? bestFloors / milestoneFloors : 0 }
    /// Height of the next milestone, in floors.
    var nextMilestone: Int { (milestonesReached + 1) * milestoneFloors }

    /// - Returns: The milestones passed by this new height, lowest first (empty when none).
    mutating func reach(_ newFloors: Int) -> [Milestone] {
        floors = max(0, newFloors)
        let before = milestonesReached
        bestFloors = max(bestFloors, floors)
        guard milestonesReached > before else { return [] }
        return (before + 1...milestonesReached).map {
            Milestone(floors: $0 * milestoneFloors, gems: gemsPerMilestone)
        }
    }

    /// Height in whole floors of a tower whose top stands `height` above the platform.
    static func floors(height: CGFloat, unit: CGFloat) -> Int {
        guard unit > 0 else { return 0 }
        return max(0, Int((height / unit).rounded()))
    }
}
