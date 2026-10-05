import CoreGraphics
import Testing
@testable import Empile

/// Only stone bars of 3: predictable shapes for the rules tests.
private let barsOnly = PieceSupply(
    shapes: [WeightedShape(shape: .bar3, weight: 1)],
    odds: MaterialOdds(hazard: 0, hazardPerLevel: 0, maxHazard: 0, gold: 0)
)

@MainActor
@Suite("A climb, from the hand to the last life")
struct GameSessionTests {
    private func makeSession(supply: PieceSupply = PieceSupply(), lives: Int = 3) -> GameSession {
        GameSession(seed: 42, supply: supply, handSize: 3, lives: lives)
    }

    private func place(_ session: GameSession, _ id: Card.ID) {
        _ = session.pickUp(id)
        session.placeHeldCard()
    }

    @Test func aGameStartsWithAFullHandAndEveryLife() {
        let session = makeSession()
        #expect(session.phase == .playing)
        #expect(session.hand.count == 3)
        #expect(Set(session.hand.map(\.id)).count == 3)
        #expect(session.selectedCardID == session.hand.first?.id)
        #expect(session.lives == 3)
        for ability in Ability.allCases {
            #expect(session.abilities.count(of: ability) == Tuning.Abilities.startingCount)
        }
        #expect(session.adRewardsLeft == Tuning.Abilities.adRewardsPerGame)
    }

    @Test func theReserveIsEveryPieceButTheOneToPlace() {
        let session = makeSession()
        #expect(session.reserve.map(\.id) == [1, 2])
        session.select(2)
        #expect(session.selectedCardID == 2)
        #expect(session.reserve.map(\.id) == [0, 1])
    }

    @Test func aPlacedPieceIsReplacedAtOnceInItsSlot() {
        let session = makeSession()
        let placed = session.hand[1].id
        place(session, placed)
        #expect(session.hand.count == 3)
        #expect(!session.hand.contains { $0.id == placed })
        #expect(session.selectedCardID == session.hand[1].id)
    }

    @Test func onlyOneBlockCanBeHeldAtATime() {
        let session = makeSession()
        let first = session.hand[0].id
        #expect(session.pickUp(first) != nil)
        #expect(session.pickUp(session.hand[1].id) == nil)
        #expect(session.heldCardID == first)
    }

    @Test func aReturnedBlockStaysInTheHand() {
        let session = makeSession()
        let card = session.hand[0].id
        _ = session.pickUp(card)
        session.returnHeldCard()
        #expect(session.heldCardID == nil)
        #expect(session.hand.contains { $0.id == card })
    }

    @Test func rotatingTurnsTheHeldBlockElseTheSelectedOne() throws {
        let session = makeSession(supply: barsOnly)
        let selected = try #require(session.activeCard)
        #expect(session.rotateActiveCard()?.shape == BlockShape.bar3.quarterTurned)
        _ = session.pickUp(session.hand[1].id)
        #expect(session.rotateActiveCard()?.id == session.hand[1].id)
        #expect(session.hand.first { $0.id == selected.id }?.shape == BlockShape.bar3.quarterTurned)
    }

    @Test func squarePiecesCannotRotate() {
        let squares = PieceSupply(shapes: [WeightedShape(shape: .square, weight: 1)], odds: barsOnly.odds)
        let session = makeSession(supply: squares)
        #expect(!session.canRotate)
        #expect(session.rotateActiveCard() == nil)
    }

    @Test func eachMilestoneIsReachedOnce() {
        let session = makeSession()
        let floors = Tuning.Climb.milestoneFloors
        #expect(session.reportHeight(floors - 1).isEmpty)
        #expect(session.reportHeight(floors) == [Milestone(floors: floors)])
        // The tower shrinks, then climbs back: no second milestone.
        session.reportHeight(floors - 2)
        #expect(session.reportHeight(floors).isEmpty)
        #expect(session.lastMilestone?.floors == floors)
    }

    @Test func aBigJumpPaysEveryMilestonePassed() {
        let session = makeSession()
        let passed = session.reportHeight(Tuning.Climb.milestoneFloors * 2 + 1)
        #expect(passed.count == 2)
        #expect(session.climb.nextMilestone == 3 * Tuning.Climb.milestoneFloors)
    }

    @Test func losingTheLastLifeEndsTheGame() {
        let session = makeSession(lives: 2)
        session.loseLife()
        #expect(session.phase == .playing)
        #expect(session.lives == 1)
        session.loseLife()
        #expect(session.phase == .gameOver)
        #expect(session.pickUp(session.hand[0].id) == nil)
        #expect(session.reportHeight(Tuning.Climb.milestoneFloors).isEmpty)
        #expect(!session.canUse(.extraLife))
    }

    @Test func aNewGameStartsFromScratch() {
        let session = makeSession()
        session.reportHeight(2 * Tuning.Climb.milestoneFloors)
        session.loseLife()
        session.useExtraLife()
        session.startPull()
        session.earnAbility()
        place(session, session.hand[0].id)
        session.startNewGame()
        #expect(session.phase == .playing)
        #expect(session.lives == 3)
        #expect(session.abilities == AbilityStock(each: Tuning.Abilities.startingCount))
        #expect(session.adRewardsLeft == Tuning.Abilities.adRewardsPerGame)
        #expect(!session.isPulling)
        #expect(session.climb.bestFloors == 0)
        #expect(session.lastMilestone == nil)
        #expect(session.hand.map(\.id) == [0, 1, 2])
    }

    @Test func changingMaterialUsesThePowerAndChangesOnlyThatPiece() {
        let session = makeSession(supply: barsOnly)
        let before = session.hand
        #expect(session.change(before[2].id, with: .rematerial))
        #expect(session.hand[0] == before[0])
        #expect(session.hand[1] == before[1])
        #expect(session.hand[2].id == before[2].id)
        #expect(session.hand[2].shape == before[2].shape)
        #expect(session.hand[2].kind != before[2].kind)
        #expect(session.abilities.count(of: .rematerial) == 0)
        #expect(!session.change(before[0].id, with: .rematerial))
    }

    @Test func reshapingGivesAnotherShapeAndKeepsTheMaterial() {
        let session = makeSession()
        let before = session.hand[0]
        #expect(session.change(before.id, with: .reshape))
        #expect(session.hand[0].id == before.id)
        #expect(session.hand[0].kind == before.kind)
        #expect(session.hand[0].shape.family != before.shape.family)
        #expect(session.abilities.count(of: .reshape) == 0)
    }

    @Test func onlyShapeAndMaterialPowersChangeAPiece() {
        let session = makeSession()
        #expect(!session.change(session.hand[0].id, with: .pull))
        #expect(session.abilities.count(of: .pull) == 1)
    }

    @Test func theLifePowerAddsALifeUpToTheLimit() {
        let session = makeSession()
        #expect(session.useExtraLife())
        #expect(session.lives == 4)
        #expect(!session.useExtraLife())
        let full = makeSession(lives: Tuning.Abilities.maxLives)
        #expect(!full.canUse(.extraLife))
    }

    @Test func theRopeLastsItsTimeThenEnds() {
        let session = makeSession()
        #expect(session.startPull())
        #expect(session.pullTimeLeft == Tuning.Abilities.pullDuration)
        #expect(!session.canUse(.pull))
        session.tickPull(Tuning.Abilities.pullDuration - 0.25)
        #expect(session.pullTimeLeft == 0.3)
        session.tickPull(0.3)
        #expect(session.pullTimeLeft == nil)
        #expect(!session.startPull())
    }

    @Test func noPowerWhileAPieceIsHeld() {
        let session = makeSession()
        _ = session.pickUp(session.hand[0].id)
        for ability in Ability.allCases {
            #expect(!session.canUse(ability))
        }
        #expect(!session.change(session.hand[1].id, with: .reshape))
    }

    @Test func eachAdGivesOnePowerUntilNoneAreLeft() throws {
        let session = makeSession()
        for left in stride(from: Tuning.Abilities.adRewardsPerGame - 1, through: 0, by: -1) {
            let won = try #require(session.earnAbility())
            #expect(session.abilities.count(of: won) >= Tuning.Abilities.startingCount + 1)
            #expect(session.adRewardsLeft == left)
        }
        #expect(!session.canEarnAbility)
        #expect(session.earnAbility() == nil)
    }
}

@Suite("Piece supply")
struct PieceSupplyTests {
    @Test func piecesAreRandomButReproducible() {
        var first = PieceSupply()
        var second = PieceSupply()
        var firstGenerator = SeededGenerator(seed: 7)
        var secondGenerator = SeededGenerator(seed: 7)
        for _ in 0..<20 {
            #expect(first.next(level: 0, using: &firstGenerator) == second.next(level: 0, using: &secondGenerator))
        }
    }

    @Test func everyPieceHasItsOwnIDAndNeverRepeatsTheLastShape() {
        var supply = PieceSupply()
        var generator = SeededGenerator(seed: 3)
        let pieces = (0..<200).map { _ in supply.next(level: 0, using: &generator) }
        #expect(Set(pieces.map(\.id)).count == pieces.count)
        for (previous, next) in zip(pieces, pieces.dropFirst()) {
            #expect(previous.shape.family != next.shape.family)
        }
    }

    @Test func trickyPiecesGrowMoreCommonWithHeight() {
        let odds = Tuning.Supply.odds
        #expect(odds.hazardChance(level: 5) > odds.hazardChance(level: 0))
        #expect(odds.hazardChance(level: 1000) == odds.maxHazard)
        func trickyShare(level: Int) -> Int {
            var supply = PieceSupply()
            var generator = SeededGenerator(seed: 11)
            return (0..<2000).filter { _ in
                let kind = supply.next(level: level, using: &generator).kind
                return kind == .spring || kind == .glass
            }.count
        }
        #expect(trickyShare(level: 8) > trickyShare(level: 0))
    }

    @Test func everyShapeDealtFitsOnThePlatform() {
        for entry in Tuning.Supply.shapes {
            let widest = max(entry.shape.columns, entry.shape.rows)
            #expect(CGFloat(widest) * Tuning.World.unit <= Tuning.World.platformSize.width)
        }
    }
}

@Suite("Height and milestones")
struct ClimbProgressTests {
    @Test func heightRoundsToTheNearestFloor() {
        #expect(ClimbProgress.floors(height: 0, unit: 36) == 0)
        #expect(ClimbProgress.floors(height: 70, unit: 36) == 2)
        #expect(ClimbProgress.floors(height: 50, unit: 36) == 1)
        #expect(ClimbProgress.floors(height: -10, unit: 36) == 0)
    }

    @Test func theBestHeightNeverGoesDown() {
        var climb = ClimbProgress(milestoneFloors: 5)
        _ = climb.reach(7)
        _ = climb.reach(4)
        #expect(climb.floors == 4)
        #expect(climb.bestFloors == 7)
        #expect(climb.milestonesReached == 1)
    }
}

@Suite("Wind")
struct WindTests {
    private func schedule(seed: UInt64 = 5) -> WindSchedule {
        WindSchedule(pause: 2...2, warning: 1, gust: 3...3, seed: seed)
    }

    @Test func calmThenWarningThenGustThenCalmAgain() {
        var wind = schedule()
        #expect(wind.advance(by: 1.9, isActive: true).phase == .calm)
        #expect(wind.advance(by: 0.2, isActive: true).phase == .warning)
        #expect(wind.advance(by: 1, isActive: true).phase == .blowing)
        #expect(wind.advance(by: 3, isActive: true).phase == .calm)
    }

    @Test func aGustRisesThenDiesDown() {
        var wind = schedule()
        wind.advance(by: 3.01, isActive: true)
        let start = wind.state.strength
        let peak = wind.advance(by: 1.5, isActive: true).strength
        let end = wind.advance(by: 1.45, isActive: true).strength
        #expect(start < 0.05)
        #expect(abs(peak - 1) < 0.01)
        #expect(end < 0.1)
        #expect(wind.state.phase == .blowing)
    }

    @Test func nothingBlowsWhileInactive() {
        var wind = schedule()
        #expect(wind.advance(by: 10, isActive: false) == .calm)
        wind.advance(by: 3.5, isActive: true)
        #expect(wind.state.phase == .blowing)
        #expect(wind.advance(by: 0.1, isActive: false).phase == .calm)
    }

    @Test func gustsComeFromBothSides() {
        var wind = schedule(seed: 9)
        var directions: Set<CGFloat> = []
        for _ in 0..<40 {
            wind.advance(by: 2, isActive: true)
            directions.insert(wind.state.direction)
        }
        #expect(directions == [-1, 1])
    }

    @Test func pressureGrowsWithHeightButStaysCapped() {
        #expect(Tuning.Wind.pressure(level: Tuning.Wind.startLevel + 3) > Tuning.Wind.pressure(level: Tuning.Wind.startLevel))
        #expect(Tuning.Wind.pressure(level: 1000) == Tuning.Wind.maxPressure)
    }

    @MainActor
    @Test func theWindWaitsForTheFirstMilestone() {
        let session = GameSession(seed: 1)
        #expect(!session.isWindy)
        session.reportHeight(Tuning.Climb.milestoneFloors * Tuning.Wind.startLevel)
        #expect(session.isWindy)
    }

    @MainActor
    @Test func theBannerOnlyChangesWithThePhase() {
        let session = GameSession(seed: 1)
        session.reportWind(WindState(phase: .blowing, direction: -1, strength: 0.3))
        let alert = session.windAlert
        session.reportWind(WindState(phase: .blowing, direction: -1, strength: 0.9))
        #expect(session.windAlert == alert)
        #expect(alert?.isBlowing == true)
        session.reportWind(.calm)
        #expect(session.windAlert == nil)
    }
}

@Suite("Birds")
struct BirdTests {
    private func schedule() -> BirdSchedule {
        BirdSchedule(pause: 5...5, flight: 1, perch: 3...3, seed: 2)
    }

    @Test func aVisitGoesInFliesInPerchesThenLeaves() {
        var birds = schedule()
        #expect(birds.advance(by: 4.9, isActive: true).isEmpty)
        #expect(birds.advance(by: 0.2, isActive: true) == [.arriving])
        #expect(birds.advance(by: 1, isActive: true) == [.perched])
        #expect(birds.advance(by: 3, isActive: true) == [.leaving])
        #expect(birds.advance(by: 1, isActive: true) == [.away])
    }

    @Test func noBirdComesWhileInactiveButOneThereFinishesItsVisit() {
        var birds = schedule()
        #expect(birds.advance(by: 60, isActive: false).isEmpty)
        #expect(birds.phase == .away)
        _ = birds.advance(by: 5.1, isActive: true)
        #expect(birds.phase == .arriving)
        #expect(birds.advance(by: 10, isActive: false) == [.perched, .leaving, .away])
        #expect(birds.advance(by: 60, isActive: false).isEmpty)
    }

    @Test func aScaredBirdLeavesAtOnce() {
        var birds = schedule()
        _ = birds.advance(by: 6.5, isActive: true)
        #expect(birds.phase == .perched)
        birds.scare()
        #expect(birds.phase == .leaving)
        #expect(birds.progress == 0)
    }

    @MainActor
    @Test func birdsWaitForTheirMilestone() {
        let session = GameSession(seed: 1)
        session.reportHeight(Tuning.Climb.milestoneFloors * (Tuning.Birds.startLevel - 1))
        #expect(!session.hasBirds)
        session.reportHeight(Tuning.Climb.milestoneFloors * Tuning.Birds.startLevel)
        #expect(session.hasBirds)
    }
}

@Suite("Points, combos and continuing")
struct ScoreTests {
    typealias Build = TowerBuilder
    private let ground: ClosedRange<CGFloat> = -126...126

    @Test func aStraightFullySupportedPieceIsPerfect() {
        #expect(PlacementQuality.judge(tilt: 0, supportedShare: 1) == .perfect)
        #expect(PlacementQuality.judge(tilt: 0, supportedShare: 0.5) == .good)
        #expect(PlacementQuality.judge(tilt: Tuning.Score.goodTilt * 2, supportedShare: 1) == .sloppy)
        #expect(PlacementQuality.judge(tilt: 0, supportedShare: 0.25) == .sloppy)
    }

    @Test func aPieceOnThePlatformIsFullySupported() {
        let piece = Build.piece(0, .stone, .t, floor: 0)
        let tower = Build.tower([piece])
        // The T stands on its stem: only the stem touches the ground, the arms hang over nothing.
        #expect(tower.supportedShare(of: piece, groundY: 0, groundSpan: ground, gap: 6) == 1.0 / 3.0)
        let bar = Build.piece(1, .stone, .bar3, floor: 0)
        #expect(Build.tower([bar]).supportedShare(of: bar, groundY: 0, groundSpan: ground, gap: 6) == 1)
    }

    @Test func aPieceOverhangingHalfwayIsHalfSupported() {
        let lower = Build.block(0, .stone, columns: 2, x: 0, floor: 0)
        let upper = Build.block(1, .stone, columns: 2, x: 1, floor: 1)
        let share = Build.tower([lower, upper]).supportedShare(of: upper, groundY: 0, groundSpan: ground, gap: 6)
        #expect(share == 0.5)
    }

    @Test func aPieceFillingANotchIsFullySupported() {
        // An L, and a single square sitting on its foot beside the tall column.
        let l = Build.piece(0, .stone, .l, floor: 0)
        let square = Build.piece(1, .stone, .mono, x: 0.5, floor: 1)
        #expect(Build.tower([l, square]).supportedShare(of: square, groundY: 0, groundSpan: ground, gap: 6) == 1)
    }

    @Test func piecesEarnTheirSquaresTimesTheirMaterial() {
        let placement = PlacementScore(kind: .glass, shape: .t, quality: .good, combo: Combo())
        #expect(placement.points == 4 * Tuning.Score.glassPerCell)
    }

    @Test func perfectPlacementsInARowRaiseTheMultiplierUpToACap() {
        var combo = Combo()
        combo.record(.perfect)
        #expect(combo.multiplier == 1 + Tuning.Score.comboStep)
        combo.record(.good)
        #expect(combo.streak == 1)
        for _ in 0..<50 {
            combo.record(.perfect)
        }
        #expect(combo.multiplier == 1 + Tuning.Score.comboStep * Double(Tuning.Score.maxComboStreak))
        combo.record(.sloppy)
        #expect(combo.multiplier == 1)
    }

    @MainActor
    @Test func theSessionAddsUpPointsAndALostPieceBreaksTheCombo() throws {
        let session = GameSession(seed: 1)
        let first = try #require(session.scorePlacement(kind: .stone, shape: .domino, quality: .perfect))
        let second = try #require(session.scorePlacement(kind: .stone, shape: .domino, quality: .perfect))
        #expect(second.points > first.points)
        #expect(session.score == first.points + second.points)
        session.loseLife()
        #expect(session.combo.streak == 0)
    }
}
