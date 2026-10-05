import Foundation
import Observation

/// The state of a game, shared by the scene (which plays it) and SwiftUI (which shows it).
/// It knows nothing about physics: the scene reports what happened, the session applies the rules.
///
/// One tower, built higher and higher. The piece to place waits on screen, two more wait in reserve; each placed
/// piece is replaced at once by a new one. Every few floors a milestone makes the game harder; each piece lost
/// costs a life. Powers (one of each to start, more from ads) can be used at any time.
@MainActor
@Observable
final class GameSession {
    enum Phase: Equatable, Sendable {
        case playing
        case gameOver
    }

    private(set) var phase = Phase.playing
    /// The piece to place (the selected one) and the reserve, including the one being dragged.
    private(set) var hand: [Card] = []
    private(set) var heldCardID: Card.ID?
    private(set) var selectedCardID: Card.ID?
    private(set) var lives: Int
    private(set) var abilities = AbilityStock(each: Tuning.Abilities.startingCount)
    /// Ads the player may still watch this game, each one for a power.
    private(set) var adRewardsLeft = Tuning.Abilities.adRewardsPerGame
    /// While the rope is available: the seconds left, in tenths.
    private(set) var pullTimeLeft: TimeInterval?
    private(set) var climb: ClimbProgress
    /// The latest milestone reached, for the banner.
    private(set) var lastMilestone: Milestone?
    /// A gust coming or blowing, for the banner.
    private(set) var windAlert: WindAlert?
    /// Points earned this game: every piece placed, multiplied by the combo.
    private(set) var score = 0
    private(set) var combo = Combo()

    @ObservationIgnored private let startingSupply: PieceSupply
    @ObservationIgnored private var supply: PieceSupply
    @ObservationIgnored private let handSize: Int
    @ObservationIgnored private let startingLives: Int
    @ObservationIgnored private var generator: SeededGenerator
    /// The exact time left on the rope; `pullTimeLeft` only changes every tenth of a second.
    @ObservationIgnored private var pullClock: TimeInterval = 0

    init(
        seed: UInt64 = .random(in: .min ... .max),
        supply: PieceSupply = PieceSupply(),
        handSize: Int = Tuning.Climb.handSize,
        lives: Int = Tuning.Climb.lives
    ) {
        startingSupply = supply
        self.supply = supply
        self.handSize = handSize
        startingLives = lives
        self.lives = lives
        generator = SeededGenerator(seed: seed)
        climb = ClimbProgress(milestoneFloors: Tuning.Climb.milestoneFloors)
        refillHand()
    }

    var isPlaying: Bool { phase == .playing }
    var maxLives: Int { startingLives }
    /// The card the rotate button acts on: the one being dragged, otherwise the selected one.
    var activeCard: Card? { hand.first { $0.id == (heldCardID ?? selectedCardID) } }
    /// The pieces waiting in reserve, in the order they are shown.
    var reserve: [Card] { hand.filter { $0.id != selectedCardID } }
    var canRotate: Bool { isPlaying && !(activeCard?.shape.isTurnInvariant ?? true) }

    // MARK: - Game

    func startNewGame() {
        supply = startingSupply
        lives = startingLives
        abilities = AbilityStock(each: Tuning.Abilities.startingCount)
        adRewardsLeft = Tuning.Abilities.adRewardsPerGame
        endPull()
        climb = ClimbProgress(milestoneFloors: climb.milestoneFloors)
        lastMilestone = nil
        windAlert = nil
        score = 0
        combo = Combo()
        hand = []
        heldCardID = nil
        phase = .playing
        refillHand()
    }

    /// The still tower now stands this many floors high.
    /// - Returns: The milestones it just passed.
    @discardableResult
    func reportHeight(_ floors: Int) -> [Milestone] {
        guard isPlaying else { return [] }
        let reached = climb.reach(floors)
        if let last = reached.last {
            lastMilestone = last
        }
        return reached
    }

    /// The wind is gusting the tower when it climbs past the first milestone.
    var isWindy: Bool { isPlaying && climb.milestonesReached >= Tuning.Wind.startLevel }

    /// Birds visit the tower once it climbs past the second milestone.
    var hasBirds: Bool { isPlaying && climb.milestonesReached >= Tuning.Birds.startLevel }

    func reportWind(_ state: WindState) {
        let alert = WindAlert(state)
        if alert != windAlert {
            windAlert = alert
        }
    }

    /// A piece has settled in the tower: it earns its points, multiplied by the combo.
    /// - Returns: What it earned, or `nil` once the game is over.
    @discardableResult
    func scorePlacement(kind: BlockKind, shape: BlockShape, quality: PlacementQuality) -> PlacementScore? {
        guard isPlaying else { return nil }
        combo.record(quality)
        let placement = PlacementScore(kind: kind, shape: shape, quality: quality, combo: combo)
        score += placement.points
        return placement
    }

    /// A piece fell out of the tower: a life is lost and the combo breaks.
    func loseLife() {
        guard isPlaying else { return }
        combo.reset()
        lives = max(0, lives - 1)
        if lives == 0 {
            heldCardID = nil
            endPull()
            phase = .gameOver
        }
    }

    // MARK: - Building

    /// Makes a piece of the reserve the one to place; the one it replaces goes to the reserve.
    func select(_ id: Card.ID) {
        guard isPlaying, heldCardID == nil, hand.contains(where: { $0.id == id }) else { return }
        selectedCardID = id
    }

    /// Turns a card a quarter turn: the one being dragged, otherwise the selected one.
    @discardableResult
    func rotateActiveCard() -> Card? {
        guard canRotate, let id = activeCard?.id, let index = hand.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        hand[index].shape = hand[index].shape.quarterTurned
        return hand[index]
    }

    func pickUp(_ id: Card.ID) -> Card? {
        guard isPlaying, heldCardID == nil, let card = hand.first(where: { $0.id == id }) else { return nil }
        heldCardID = id
        selectedCardID = id
        return card
    }

    func returnHeldCard() {
        heldCardID = nil
    }

    /// The held piece is now in the world: a new one takes its place in the hand right away.
    func placeHeldCard() {
        guard let id = heldCardID, let index = hand.firstIndex(where: { $0.id == id }) else { return }
        heldCardID = nil
        hand[index] = supply.next(level: climb.milestonesReached, using: &generator)
        selectedCardID = hand[index].id
    }

    // MARK: - Powers

    /// Whether a power can be used now: one is left, a game is on, nothing is in the player's fingers.
    func canUse(_ ability: Ability) -> Bool {
        guard isPlaying, heldCardID == nil, abilities.count(of: ability) > 0 else { return false }
        switch ability {
        case .reshape, .rematerial: return true
        case .pull: return pullTimeLeft == nil
        case .extraLife: return lives < Tuning.Abilities.maxLives
        }
    }

    /// Gives a piece another shape (`.reshape`) or a random material (`.rematerial`).
    /// - Returns: Whether the power was used.
    @discardableResult
    func change(_ id: Card.ID, with ability: Ability) -> Bool {
        guard ability.needsPiece, canUse(ability), let index = hand.firstIndex(where: { $0.id == id }),
              abilities.use(ability)
        else { return false }
        hand[index] = ability == .reshape
            ? supply.reshaped(hand[index], using: &generator)
            : supply.rematerialized(hand[index], using: &generator)
        return true
    }

    /// - Returns: Whether the power was used.
    @discardableResult
    func useExtraLife() -> Bool {
        guard canUse(.extraLife), abilities.use(.extraLife) else { return false }
        lives += 1
        return true
    }

    /// The rope is available for `Tuning.Abilities.pullDuration` seconds.
    /// - Returns: Whether the power was used.
    @discardableResult
    func startPull() -> Bool {
        guard canUse(.pull), abilities.use(.pull) else { return false }
        pullClock = Tuning.Abilities.pullDuration
        pullTimeLeft = pullClock
        return true
    }

    /// Time passes for the rope, while the game runs.
    func tickPull(_ deltaTime: TimeInterval) {
        guard pullTimeLeft != nil else { return }
        pullClock -= max(0, deltaTime)
        guard pullClock > 0 else {
            endPull()
            return
        }
        let shown = (pullClock * 10).rounded(.up) / 10
        if shown != pullTimeLeft {
            pullTimeLeft = shown
        }
    }

    var isPulling: Bool { pullTimeLeft != nil }

    /// Whether an ad can still be watched for a power this game.
    var canEarnAbility: Bool { isPlaying && adRewardsLeft > 0 }

    /// The player watched an ad through: one power drawn at random joins the stock.
    /// - Returns: The power won, or `nil` when no ad reward is left.
    @discardableResult
    func earnAbility() -> Ability? {
        guard canEarnAbility, let won = Ability.allCases.randomElement(using: &generator) else { return nil }
        adRewardsLeft -= 1
        abilities.add(won)
        return won
    }

    private func endPull() {
        pullClock = 0
        pullTimeLeft = nil
    }

    private func refillHand() {
        while hand.count < handSize {
            hand.append(supply.next(level: climb.milestonesReached, using: &generator))
        }
        selectedCardID = hand.first?.id
    }
}
