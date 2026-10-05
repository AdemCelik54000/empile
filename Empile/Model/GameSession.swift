import Foundation
import Observation

/// The state of a game, shared by the scene (which plays it) and SwiftUI (which shows it).
/// It knows nothing about physics: the scene reports what happened, the session applies the rules.
///
/// One tower, built higher and higher. Each placed piece is replaced at once by a new one; every few floors
/// a milestone gives gems to spend in the shop; each piece lost costs a life.
@MainActor
@Observable
final class GameSession {
    enum Phase: Equatable, Sendable {
        case playing
        case gameOver
    }

    private(set) var phase = Phase.playing
    /// The pieces the player can choose from, including the one being dragged.
    private(set) var hand: [Card] = []
    private(set) var heldCardID: Card.ID?
    private(set) var selectedCardID: Card.ID?
    private(set) var lives: Int
    private(set) var gems = 0
    private(set) var climb: ClimbProgress
    /// The latest milestone reached, for the banner.
    private(set) var lastMilestone: Milestone?
    /// A gust coming or blowing, for the banner.
    private(set) var windAlert: WindAlert?
    /// Points earned this game: every piece placed, multiplied by the combo.
    private(set) var score = 0
    private(set) var combo = Combo()
    /// Times this game was continued after watching an ad.
    private(set) var continuesUsed = 0

    @ObservationIgnored private let startingSupply: PieceSupply
    @ObservationIgnored private var supply: PieceSupply
    @ObservationIgnored private let handSize: Int
    @ObservationIgnored private let startingLives: Int
    @ObservationIgnored private var generator: SeededGenerator

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
        climb = ClimbProgress(milestoneFloors: Tuning.Climb.milestoneFloors, gemsPerMilestone: Tuning.Climb.milestoneGems)
        refillHand()
    }

    var isPlaying: Bool { phase == .playing }
    var maxLives: Int { startingLives }
    /// The card the rotate button and the shop act on: the one being dragged, otherwise the selected one.
    var activeCard: Card? { hand.first { $0.id == (heldCardID ?? selectedCardID) } }
    var canRotate: Bool { isPlaying && !(activeCard?.shape.isTurnInvariant ?? true) }

    // MARK: - Game

    func startNewGame() {
        supply = startingSupply
        lives = startingLives
        gems = 0
        climb = ClimbProgress(milestoneFloors: climb.milestoneFloors, gemsPerMilestone: climb.gemsPerMilestone)
        lastMilestone = nil
        windAlert = nil
        score = 0
        combo = Combo()
        continuesUsed = 0
        hand = []
        heldCardID = nil
        phase = .playing
        refillHand()
    }

    /// The still tower now stands this many floors high.
    /// - Returns: The milestones it just passed, each already paid in gems.
    @discardableResult
    func reportHeight(_ floors: Int) -> [Milestone] {
        guard isPlaying else { return [] }
        let reached = climb.reach(floors)
        for milestone in reached {
            gems += milestone.gems
        }
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

    /// The game can go on once more, with every life back, by watching an ad.
    var canContinue: Bool { phase == .gameOver && continuesUsed < Tuning.Ads.continuesPerGame }

    /// Every life back, the tower and the score as they were.
    func continueAfterAd() {
        guard canContinue else { return }
        continuesUsed += 1
        lives = startingLives
        phase = .playing
    }

    /// A piece fell out of the tower: a life is lost and the combo breaks.
    func loseLife() {
        guard isPlaying else { return }
        combo.reset()
        lives = max(0, lives - 1)
        if lives == 0 {
            heldCardID = nil
            phase = .gameOver
        }
    }

    // MARK: - Building

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

    // MARK: - Shop

    var canChangeMaterial: Bool { canSpend(Tuning.Shop.rematerialPrice) && activeCard != nil }
    var canReshape: Bool { canSpend(Tuning.Shop.reshapePrice) && activeCard != nil }
    var canBuyLife: Bool { canSpend(Tuning.Shop.lifePrice) && lives < startingLives }

    /// Gives the selected piece another material, picked at random.
    @discardableResult
    func changeSelectedMaterial() -> Bool {
        guard canChangeMaterial, let index = activeIndex else { return false }
        gems -= Tuning.Shop.rematerialPrice
        hand[index] = supply.rematerialized(hand[index], using: &generator)
        return true
    }

    /// Gives the selected piece another shape.
    @discardableResult
    func reshapeSelected() -> Bool {
        guard canReshape, let index = activeIndex else { return false }
        gems -= Tuning.Shop.reshapePrice
        hand[index] = supply.reshaped(hand[index], using: &generator)
        return true
    }

    @discardableResult
    func buyLife() -> Bool {
        guard canBuyLife else { return false }
        gems -= Tuning.Shop.lifePrice
        lives += 1
        return true
    }

    private var activeIndex: Int? {
        activeCard.flatMap { card in hand.firstIndex { $0.id == card.id } }
    }

    /// Nothing is bought while a piece is in the player's fingers.
    private func canSpend(_ price: Int) -> Bool {
        isPlaying && heldCardID == nil && gems >= price
    }

    private func refillHand() {
        while hand.count < handSize {
            hand.append(supply.next(level: climb.milestonesReached, using: &generator))
        }
        selectedCardID = hand.first?.id
    }
}
