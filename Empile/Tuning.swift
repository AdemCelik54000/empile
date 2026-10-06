import CoreGraphics
import Foundation

/// Every number that shapes how Empile feels. Tweak here, nowhere else.
///
/// Units: lengths in points, times in seconds, speeds in points per second.
/// SpriteKit maps 150 points to 1 meter, so gravity and density use meters.
enum Tuning {
    enum Display {
        /// ProMotion iPhones run at 120 Hz, others cap at 60 Hz automatically.
        static let preferredFramesPerSecond = 120
        /// Longest frame step our own logic accepts, so a hitch never makes anything jump.
        static let maxFrameDuration: TimeInterval = 1.0 / 30.0
    }

    enum World {
        /// Side of one grid unit. Block shapes are whole multiples of it.
        static let unit: CGFloat = 36
        /// m/s². A bit stronger than Earth's 9.8 so drops feel snappy at this scale.
        static let gravity = CGVector(dx: 0, dy: -12)
        /// SpriteKit's fixed scale between physics meters and screen points.
        static let pointsPerMeter: CGFloat = 150
        static let platformSize = CGSize(width: 7 * unit, height: 22)
        /// Width of the pillar under the platform, relative to the platform.
        static let pillarWidthRatio: CGFloat = 0.5
        static let pillarDepth: CGFloat = 240
        /// A block whose center falls this far below the platform surface is lost.
        static let lossDepth: CGFloat = 520
        /// Squares closer than this count as touching when deciding what rests on what.
        static let contactTolerance: CGFloat = 4
    }

    enum Materials {
        /// Slides a little on other pieces, like soft jelly; a well-centered piece still holds.
        static let stone = Material(
            density: 2.5,
            friction: 0.4,
            restitution: 0.06,
            linearDamping: 0.05,
            angularDamping: 0.4
        )
        /// Light, so it barely pushes the tower down; the bounce comes from its power, not its material.
        static let spring = Material(
            density: 0.8,
            friction: 0.36,
            restitution: 0.15,
            linearDamping: 0.05,
            angularDamping: 0.4
        )
        /// Slippery: blocks slide on it more easily (the engine averages the two frictions in contact).
        static let glass = Material(
            density: 2,
            friction: 0.12,
            restitution: 0.05,
            linearDamping: 0.05,
            angularDamping: 0.35
        )
        /// Very heavy and grippy: nothing slides on it. The anchor the shop sells.
        static let gold = Material(
            density: 6,
            friction: 0.85,
            restitution: 0,
            linearDamping: 0.05,
            angularDamping: 0.6
        )
        static let platform = Material(
            density: 1,
            friction: 0.9,
            restitution: 0,
            linearDamping: 0,
            angularDamping: 0
        )
    }

    enum Physics {
        /// Physics bodies are this much smaller than the drawing on each side: neighbours overlap a hair,
        /// like soft pieces pressed together, and a piece fits into a gap barely as wide as itself.
        static let bodyInset: CGFloat = 1
        /// The outer corners of a body are cut this much, so pieces slide past edges into gaps instead of
        /// catching on them.
        static let bodyChamfer: CGFloat = 5
        /// Below these speeds a block counts as still.
        static let calm = CalmThreshold(linearSpeed: 2, angularSpeed: 0.03)
        /// How long every block must stay still before the tower counts as stable.
        static let settleDuration: TimeInterval = 0.5
        /// Above this speed a block uses continuous collision so it can never pass through another.
        static let preciseCollisionSpeed: CGFloat = 250
        /// Once the tower is stable, put every body to sleep: no slow creeping, no micro jitter.
        /// The next impact wakes them up.
        static let restsWhenStable = true
        static let simulationSpeed: CGFloat = 1
    }

    enum Drag {
        /// Screen gap between the fingertip and the bottom of the held block, so the finger never hides it.
        static let fingerGap: CGFloat = 48
        /// How tightly the held block follows the finger. Higher = stiffer, lower = floatier.
        static let followSharpness: Double = 30
        /// Minimum gap between the held block and the top of the tower.
        static let clearanceAboveTower: CGFloat = 18
        /// The next piece waits in the air this far above the tower, until a finger takes it.
        static let readyLift: CGFloat = 150
        /// How quickly the waiting piece follows the tower as it grows.
        static let readySharpness: Double = 6
        /// Screen margin kept between the held block and the screen sides.
        static let sideMargin: CGFloat = 8
        /// With the camera peeking to a side, share of the block's width that may stick out of the screen.
        static let edgeOverhang: CGFloat = 2.0 / 3.0
        /// Share of the finger's horizontal speed given to the block when released: none, a piece lets go
        /// and simply falls where it was.
        static let inheritedVelocityFactor: CGFloat = 0
        static let maxInheritedSpeed: CGFloat = 240
        /// The release speed is measured over this last stretch of the gesture.
        static let velocityWindow: TimeInterval = 0.08
        static let velocitySampleCapacity = 32
        /// A new block pops in from this scale, with a slight overshoot.
        static let appearScale: CGFloat = 0.6
        static let appearDuration: TimeInterval = 0.22
        static let turnDuration: TimeInterval = 0.14
        static let dismissDuration: TimeInterval = 0.18
    }

    enum Camera {
        /// Screen space kept free above the tower top, for holding the next block.
        static let headroom: CGFloat = 260
        /// Screen space kept visible between the platform surface and the hand.
        static let floorMargin: CGFloat = 80
        /// Largest zoom-out (1 = none). Past it, the camera follows the top instead.
        static let maxZoomOut: CGFloat = 1
        /// How quickly the camera catches up. Lower = softer.
        static let sharpness: Double = 4
        /// Finger at the very edge of the screen for a moment: the camera peeks to that side.
        /// Distance from the screen side that counts as the edge, and how long the finger must stay.
        static let edgeWidth: CGFloat = 18
        static let edgeDwell: TimeInterval = 0.18
        static let edgeSharpness: Double = 5
        /// At full push: how far the camera moves sideways (screen points) and how much it zooms out.
        static let edgePan: CGFloat = 36
        static let edgeZoomOut: CGFloat = 0.06
    }

    enum Tutorial {
        /// The first game shows how to play for this many pieces placed.
        static let placements = 3
        static let ringSize: CGFloat = 92
    }

    enum Climb {
        static let lives = 3
        /// Pieces to choose from; each one placed is replaced at once.
        static let handSize = 3
        /// Floors between two milestones: each one raises the difficulty.
        static let milestoneFloors = 5
        /// A piece out of sight below the screen that falls faster than this is lost; a still one is frozen.
        static let lostFallSpeed: CGFloat = 120
        /// How quickly the pieces of a finished game fade away.
        static let clearDuration: TimeInterval = 0.25
        /// How long the milestone banner stays on screen.
        static let bannerDuration: TimeInterval = 2.2
    }

    enum Supply {
        /// The shapes dealt, and how often each one shows up (higher weight = more often).
        static let shapes = [
            WeightedShape(shape: .domino, weight: 3),
            WeightedShape(shape: .bar3, weight: 3),
            WeightedShape(shape: .corner, weight: 3),
            WeightedShape(shape: .bar4, weight: 2),
            WeightedShape(shape: .square, weight: 3),
            WeightedShape(shape: .t, weight: 3),
            WeightedShape(shape: .l, weight: 3),
            WeightedShape(shape: .j, weight: 3),
            WeightedShape(shape: .s, weight: 2),
            WeightedShape(shape: .z, weight: 2),
            WeightedShape(shape: .mono, weight: 1),
        ]
        /// Spring pieces grow slightly more common with each milestone, at most about 1 in 15; gold stays rare.
        static let odds = MaterialOdds(hazard: 0.04, hazardPerLevel: 0.004, maxHazard: 0.067, gold: 0.04)
    }

    enum Score {
        /// Points for each square of a piece, by material: the tricky ones are worth more, the gold anchor less.
        static let stonePerCell = 10
        static let springPerCell = 12
        static let glassPerCell = 15
        static let goldPerCell = 6
        /// A placement is perfect when the piece leans less than this (radians) and its whole underside rests
        /// on something; good when it leans less than `goodTilt` and at least `goodSupport` of it is supported.
        static let perfectTilt: CGFloat = 0.05
        static let goodTilt: CGFloat = 0.14
        static let goodSupport = 0.5
        /// Squares closer than this vertically count as resting on each other.
        static let supportGap: CGFloat = 6
        /// Each perfect placement in a row adds this to the multiplier, up to `maxComboStreak` steps (× 3).
        static let comboStep = 0.25
        static let maxComboStreak = 8
    }

    enum Celebration {
        // Floating points over a piece once it has settled.
        static let labelFontSize: CGFloat = 20
        static let perfectFontSize: CGFloat = 24
        static let labelRise: CGFloat = 46
        static let labelDuration: TimeInterval = 1.1
        static let labelStartScale: CGFloat = 0.4
        /// A sloppy placement's points are shown fainter.
        static let sloppyOpacity: CGFloat = 0.55
        static let labelShadowOpacity: CGFloat = 0.25
        static let labelShadowOffset: CGFloat = 1.5
        /// Space between the top of the piece and its floating points.
        static let labelGap: CGFloat = 14
        // Sparkles: a few for a perfect placement, more as the combo grows, a shower for milestones and records.
        static let sparkleSize: CGFloat = 12
        /// How much the sides of a sparkle curve in (0 = straight, 0.5 = very thin).
        static let sparklePinch: CGFloat = 0.12
        static let perfectSparkles = 14
        static let sparklesPerStreak = 4
        static let maxComboSparkles = 46
        static let milestoneSparkles = 50
        static let recordSparkles = 90
        static let sparkleSpeed: ClosedRange<CGFloat> = 50...190
        static let sparkleLifetime: CGFloat = 0.9
        static let sparkleSpin: CGFloat = 5
        static let sparkleBirthRate: CGFloat = 400
        /// Width of the shower over the tower top, for milestones and records.
        static let showerWidth: CGFloat = 220
        // A perfect piece lights up and pops.
        static let flashDuration: TimeInterval = 0.32
        static let flashStrength: CGFloat = 0.65
        static let flashPop: CGFloat = 0.08
        // A rising chime: one semitone higher with each perfect placement in a row.
        static let chimeVolume: Float = 0.5
        static let semitonesPerStreak: Float = 2
        static let maxChimeSemitones: Float = 16
        static let recordVolume: Float = 0.65
    }

    enum Wind {
        /// Gusts start once this many milestones are passed, so the first floors are calm.
        static let startLevel = 1
        /// Calm time between two gusts, the warning before one, and how long a gust lasts.
        static let pause: ClosedRange<TimeInterval> = 9...16
        static let warning: TimeInterval = 1.6
        static let gust: ClosedRange<TimeInterval> = 2.8...4
        /// Push of a row of wind at the peak of a gust, as a share of the weight of a slice of stone (see `catchDepth`).
        /// A wide, well-built tower holds; a thin column a few pieces tall tips over; glass slides off.
        static let pressure: CGFloat = 0.05
        /// Added for each milestone past `startLevel`, up to `maxPressure`.
        static let pressurePerLevel: CGFloat = 0.01
        static let maxPressure: CGFloat = 0.12
        /// The wind blows in horizontal rows this far apart; each row pushes the first piece it meets.
        static let rowSpacing: CGFloat = World.unit / 4
        /// How deep into a piece a row of wind counts, for its push: the bigger, the harder the wind hits.
        static let catchDepth: CGFloat = World.unit * 2.5
        /// Rows start this far beyond the outermost piece.
        static let rayMargin: CGFloat = World.unit * 4
        // Streaks.
        static let maxStreaksPerSecond: CGFloat = 70
        static let maxStreaks = 90
        /// Share of the streaks shown during the warning.
        static let warningStreakShare: CGFloat = 0.2
        /// Time a streak takes to cross the screen at full gust.
        static let streakLifetime: CGFloat = 0.9
        /// Length of a streak's trail, in screen points.
        static let streakLength: CGFloat = 80
        static let streakThickness: CGFloat = 2.5
        static let streakOpacity: CGFloat = 0.6
        /// How far ahead of its head a streak looks for pieces in its way.
        static let streakLookAhead: CGFloat = 10
        /// When a piece is in the way: climb or dive speed, as a share of the streak speed, and forward speed left.
        static let streakDeflection: CGFloat = 1.3
        static let streakSlowdown: CGFloat = 0.35
        /// How quickly a streak straightens again once past a piece (1/s).
        static let streakRecovery: CGFloat = 3
        /// A streak looks for a way round up to `streakProbeSteps × streakProbeSpacing` above and below.
        static let streakProbeSteps = 10
        static let streakProbeSpacing: CGFloat = World.unit / 3
        /// Distance between two points of a streak's trail.
        static let streakPointSpacing: CGFloat = 4
        /// A streak fades in and out over this long.
        static let streakFadeDuration: CGFloat = 0.15
        /// Streak speed is set so it would cross the screen plus this share of its width.
        static let streakStartOffset: CGFloat = 0.6
        /// Streak speed while the gust is still faint, as a share of the full speed.
        static let streakBaseSpeed: CGFloat = 0.55
        static let gustVolume: Float = 0.12

        static func pressure(level: Int) -> CGFloat {
            min(maxPressure, Wind.pressure + pressurePerLevel * CGFloat(max(0, level - startLevel)))
        }
    }

    enum Birds {
        /// Birds start visiting once this many milestones are passed (after the wind).
        static let startLevel = 2
        /// Time between two visits, to fly in or off, and to stay perched.
        static let pause: ClosedRange<TimeInterval> = 14...24
        static let flight: TimeInterval = 1.3
        static let perch: ClosedRange<TimeInterval> = 3...4.5
        /// Downward push where the bird stands, in newtons: about one and a half stone squares.
        static let weight: CGFloat = 2.4
        /// Lands on a piece whose top is at most this far below the highest one.
        static let perchDepth: CGFloat = 2 * World.unit
        /// Where on a square it may stand, as a share of a square either side of its middle.
        static let footholdJitter: CGFloat = 0.3
        /// Room needed above a square for the bird to stand on it.
        static let clearance: CGFloat = 6
        /// Its piece tilting more than this (radians) scares it away.
        static let maxTilt: CGFloat = 0.35
        static let size = CGSize(width: 30, height: 24)
        /// How much darker the wing is than the body.
        static let wingShade: CGFloat = 0.15
        static let flapInterval: TimeInterval = 0.09
        /// It flies in from this high above its perch, along an arc this tall.
        static let flightRise: CGFloat = 150
        static let flightArc: CGFloat = 40
        /// It appears and leaves this far beyond the screen edges.
        static let edgeMargin: CGFloat = 40
        /// Share of its tilt kept each frame while flying off, so it straightens up.
        static let rotationSettle: CGFloat = 0.9
        /// The piece flattens this much when the bird lands on it.
        static let landingSquash: CGFloat = 0.05
        static let chirpVolume: Float = 0.4
        /// The take-off chirp is higher.
        static let takeOffSemitones: Float = 4
    }

    enum Ads {
        /// `false` in the version for testers (branch `sans-pub`): no ad is ever loaded or shown, and the ad
        /// button gives a power straight away. This is the only line that differs between the two branches.
        static let isEnabled = true
        /// An ad is shown after this many finished games (lost or given up), then the count starts over.
        static let gamesPerAd = 5
        /// Google's public test unit: it always serves test ads and never earns or risks anything.
        static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
        /// The real unit of the AdMob account. Only the App Store version uses it (see `AdUnits`), so testers
        /// and developers never click real ads. The app ID (`ca-app-pub-8817900109973306~3491063497`) is in
        /// `Info.plist`, key `GADApplicationIdentifier`.
        static let liveInterstitialUnitID = "ca-app-pub-8817900109973306/8276486310"
        /// Google's public test unit for ads watched for a reward (here: a power drawn at random).
        static let testRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"
        /// The real rewarded unit of the AdMob account. Only the App Store version uses it.
        static let liveRewardedUnitID: String? = "ca-app-pub-8817900109973306/3873051927"
    }

    enum Abilities {
        /// Of each power, at the start of a game.
        static let startingCount = 1
        /// Ads the player may watch per game, each one for a power drawn at random.
        static let adRewardsPerGame = 3
        /// The "one more life" power cannot raise the lives above this.
        static let maxLives = 5
        /// How long the rope stays available once the power is used.
        static let pullDuration: TimeInterval = 10
        /// Pull on the roped piece: acceleration per point of rope length (1/s²). The further the finger, the
        /// harder the pull.
        static let pullStiffness: CGFloat = 32
        /// Slows the roped piece down so it does not swing forever (1/s).
        static let pullDamping: CGFloat = 10
        /// Strongest acceleration the rope gives, in points per second².
        static let maxPullAcceleration: CGFloat = 4500
        /// The roped piece never moves faster than this (points per second), so it cannot be flung off screen.
        static let maxPullSpeed: CGFloat = 900
        /// A piece carrying others is pulled harder, up to this many times (the weight on it, in own masses, plus one).
        static let maxPullLoadBoost: CGFloat = 6
        /// A touch this close to a piece (screen points) still catches it.
        static let pullCatchRadius: CGFloat = 14
        /// The rope gets thinner as it stretches: width when slack, thinnest width, and the length that
        /// makes it lose one point of width.
        static let ropeWidth: CGFloat = 5
        static let ropeMinWidth: CGFloat = 1.5
        static let ropeThinningLength: CGFloat = 70
        /// How long the power's icon takes the stage when it is used, before it acts.
        static let activationDuration: TimeInterval = 0.75
        /// How long the changed piece stays on display after a shape or material change.
        static let changeDisplayDuration: TimeInterval = 0.6
        /// The roulette: how many full turns before it slows down, and the delay between two steps,
        /// first to last.
        static let rouletteTurns = 3
        static let rouletteStepDelay: ClosedRange<Double> = 0.05...0.32
        static let rouletteResultDuration: TimeInterval = 1.2
    }

    enum Powers {
        /// Glass shatters once more pieces than this rest on it.
        static let glassMaxLoad = 3
        /// Upward speed given to the block that lands on a spring (≈ 3 floors high).
        static let springLaunchSpeed: CGFloat = 620
        /// The launch speed above is for a piece this heavy (kg): a stone piece of two squares. A heavier piece
        /// is launched less high, a lighter one a little higher.
        static let springReferenceMass: CGFloat = 2.5 * 2 * pow(World.unit / World.pointsPerMeter, 2)
        /// How much the weight counts: 0 = not at all, 0.5 = the speed falls with the square root of the mass.
        static let springMassExponent: CGFloat = 0.35
        /// Bounds of the launch speed, as a share of `springLaunchSpeed`.
        static let springSpeedRange: ClosedRange<CGFloat> = 0.5...1.15

        static func springSpeed(forMass mass: CGFloat) -> CGFloat {
            guard mass > 0 else { return springLaunchSpeed }
            let share = pow(springReferenceMass / mass, springMassExponent)
            return springLaunchSpeed * share.clamped(to: springSpeedRange)
        }
        /// How vertical the contact must be to count as landing on top (1 = straight down).
        static let springContactVerticality: CGFloat = 0.6
        /// How much the spring stretches when it fires.
        static let springSquash: CGFloat = 0.3
        static let shardCount = 22
        static let shardSpeed: ClosedRange<CGFloat> = 60...240
        static let shardLifetime: CGFloat = 0.9
        static let shardSize: CGFloat = 8
        static let shardSpin: CGFloat = 9
    }

    enum Tension {
        /// A moving block tilted less than this is fine; at `fullTilt` the danger is maximal.
        static let safeTilt: CGFloat = 0.14
        static let fullTilt: CGFloat = 0.45
        /// How fast the tension rises, then fades.
        static let attackSharpness: Double = 12
        static let releaseSharpness: Double = 3
        static let droneMaxVolume: Float = 0.5
        /// The drone volume is only updated when it changes by more than this.
        static let droneVolumeStep: Float = 0.02
        /// Micro-vibrations start above this tension.
        static let hapticThreshold: CGFloat = 0.25
        static let tickInterval: ClosedRange<TimeInterval> = 0.12...0.32
        static let tickIntensity: ClosedRange<Float> = 0.12...0.3
        static let tickSharpness: Float = 0.3
    }

    enum SlowMotion {
        static let isEnabled = true
        /// Physics speed while a placed block falls off the platform.
        static let speed: CGFloat = 0.4
        static let holdDuration: TimeInterval = 0.45
        /// Time to come back to full speed.
        static let rampDuration: TimeInterval = 0.35
    }

    enum Impact {
        /// SpriteKit impulse below which a contact is ignored: resting contacts, micro bumps.
        /// At `full` and above, an impact counts as the strongest possible.
        /// `curve` below 1 makes soft impacts more noticeable.
        /// Measured: a gentle drop onto the tower ≈ 25–40, a drop from the top of the screen ≈ 240–280.
        static let scale = ImpactScale(threshold: 5, full: 260, curve: 0.6)
        /// A block ignores new impacts for this long after one, so a landing never rattles.
        static let cooldown: TimeInterval = 0.06
        /// Bigger blocks sound lower and feel duller. Reference: a 2 × 1 block.
        static let referenceArea: CGFloat = 2
    }

    enum Juice {
        // Squash: pieces are a little jelly-like. A landing block flattens, then wobbles back.
        static let squashEnabled = true
        /// Flattening at full strength (0.18 = 18 %).
        static let squashMax: CGFloat = 0.22
        /// Sideways bulge relative to the flattening, so the block keeps its volume.
        static let squashWidening: CGFloat = 0.6
        /// The block that gets hit squashes this much compared to the one landing on it.
        static let struckSquashShare: CGFloat = 0.6
        /// Even soft touches make the pieces jiggle a little.
        static let squashMinimumStrength: CGFloat = 0.025
        static let squashCompressDuration: TimeInterval = 0.05
        /// The wobble after the squash: how many swings, how long each one lasts, and how much smaller
        /// each swing is than the previous one.
        static let wobbleCount = 4
        static let wobbleHalfPeriod: TimeInterval = 0.07
        static let wobbleDecay: CGFloat = 0.6
        /// How much a piece stretches when it is let go.
        static let dropStretch: CGFloat = 0.06

        // Dust: a small puff along the contact.
        static let dustEnabled = true
        static let dustMinimumStrength: CGFloat = 0.05
        static let dustParticles: ClosedRange<CGFloat> = 5...24
        static let dustSpeed: ClosedRange<CGFloat> = 15...65
        /// Width of the puff relative to the landing block.
        static let dustSpread: CGFloat = 0.85
        static let dustLifetime: CGFloat = 0.5
        static let dustOpacity: CGFloat = 0.55
        static let dustScale: CGFloat = 0.35
        static let dustGrowth: CGFloat = 0.9
        static let dustBirthRate: CGFloat = 600
        static let dustDotSize: CGFloat = 14
        /// Puffs that can be in the air at once.
        static let dustEmitters = 8

        // Camera shake: very light, strong impacts only. Always on, whatever the system's Reduce Motion setting.
        static let shakeEnabled = true
        static let shakeMinimumStrength: CGFloat = 0.55
        /// Screen points at full strength.
        static let shakeAmplitude: CGFloat = 3.5
        static let shakeDuration: TimeInterval = 0.25
        /// Oscillations per second.
        static let shakeFrequency: Double = 22
        /// Vertical shake runs at this multiple of the horizontal one, so the motion never looks like a line.
        static let shakeVerticalRatio: Double = 1.3
        /// Shake when a piece is lost, 0...1.
        static let lostPieceShake: CGFloat = 0.8
    }

    enum Haptics {
        static let isEnabled = true
        static let impactIntensity: ClosedRange<Float> = 0.18...1
        /// Heavy stone: a dull thud rather than a crisp click.
        static let impactSharpness: ClosedRange<Float> = 0.2...0.45
        static let minimumInterval: TimeInterval = 0.03
        static let pickup = HapticTap(intensity: 0.35, sharpness: 0.7)
        static let turn = HapticTap(intensity: 0.3, sharpness: 0.9)
        static let springBounce = [HapticTap(intensity: 0.7, sharpness: 0.6), HapticTap(intensity: 0.4, sharpness: 0.8)]
        static let shatter = [
            HapticTap(intensity: 1, sharpness: 1),
            HapticTap(intensity: 0.6, sharpness: 0.9),
            HapticTap(intensity: 0.35, sharpness: 0.8),
        ]
        static let milestone = [
            HapticTap(intensity: 0.5, sharpness: 0.6),
            HapticTap(intensity: 0.65, sharpness: 0.7),
            HapticTap(intensity: 0.8, sharpness: 0.8),
            HapticTap(intensity: 1, sharpness: 0.9),
        ]
        static let lifeLost = [HapticTap(intensity: 0.8, sharpness: 0.15), HapticTap(intensity: 0.5, sharpness: 0.1)]
        static let purchase = HapticTap(intensity: 0.6, sharpness: 0.8)
        /// A crisp tap for a perfect placement.
        static let perfect = HapticTap(intensity: 0.5, sharpness: 0.85)
        static let record = [
            HapticTap(intensity: 0.6, sharpness: 0.7),
            HapticTap(intensity: 0.8, sharpness: 0.8),
            HapticTap(intensity: 1, sharpness: 0.9),
        ]
        /// A light tap when a bird lands on the tower.
        static let birdLanding = HapticTap(intensity: 0.3, sharpness: 0.6)
        /// A soft double tap when a gust is coming.
        static let windWarning = [HapticTap(intensity: 0.35, sharpness: 0.2), HapticTap(intensity: 0.25, sharpness: 0.2)]
        /// Time between the taps of a pattern.
        static let patternSpacing: TimeInterval = 0.07
        static let lifeLostSpacing: TimeInterval = 0.28
    }

    enum Sound {
        static let isEnabled = true
        static let sampleRate: Double = 44_100
        /// Sounds that can overlap.
        static let voices = 8
        static let peakLevel: Float = 0.9
        static let impactVolume: ClosedRange<Float> = 0.12...1
        /// Pitch change each time the block area doubles (negative: bigger is lower).
        static let semitonesPerSizeDoubling: Float = -2
        /// Random detune, in semitones, so repeated impacts never sound identical.
        static let pitchJitter: Float = 0.8
        static let pickupVolume: Float = 0.22
        static let turnVolume: Float = 0.3
        static let springVolume: Float = 0.7
        static let shatterVolume: Float = 0.9
        static let lifeLostVolume: Float = 0.7
        static let gameOverVolume: Float = 0.8
        static let resultVolume: Float = 0.6
        /// Notes of the milestone arpeggio, then of a lost piece's fall (semitones).
        static let milestoneArpeggio: [Float] = [0, 4, 7, 12, 16]
        static let lifeLostNotes: [Float] = [-5, -12]
        /// The sad run down when the last piece is lost (semitones).
        static let gameOverNotes: [Float] = [0, -3, -7, -12]
        static let gameOverSpacing: TimeInterval = 0.26
        /// Played together when the shop sells something.
        static let purchaseNotes: [Float] = [7, 12]
        static let arpeggioSpacing: TimeInterval = 0.08
        static let lifeLostSpacing: TimeInterval = 0.28

        /// A dull knock: low resonances that die fast, plus a short gritty click.
        static let stoneImpact = SoundRecipe(
            modes: [
                .init(frequency: 180, amplitude: 1, decay: 0.05),
                .init(frequency: 395, amplitude: 0.55, decay: 0.032),
                .init(frequency: 830, amplitude: 0.3, decay: 0.018),
                .init(frequency: 1720, amplitude: 0.14, decay: 0.009),
            ],
            noise: .init(amplitude: 0.7, decay: 0.006, brightness: 0.35),
            duration: 0.3,
            attack: 0.0008,
            release: 0.02
        )
        /// A soft, short pop.
        static let pickup = SoundRecipe(
            modes: [
                .init(frequency: 1250, amplitude: 1, decay: 0.022),
                .init(frequency: 2500, amplitude: 0.25, decay: 0.01),
            ],
            noise: .init(amplitude: 0, decay: 0.001, brightness: 0),
            duration: 0.09,
            attack: 0.002,
            release: 0.01
        )
        /// A small mechanical click.
        static let turn = SoundRecipe(
            modes: [
                .init(frequency: 950, amplitude: 1, decay: 0.012),
                .init(frequency: 2100, amplitude: 0.4, decay: 0.006),
            ],
            noise: .init(amplitude: 0.3, decay: 0.002, brightness: 0.6),
            duration: 0.05,
            attack: 0.0005,
            release: 0.008
        )
        /// A soft thump, lighter than stone.
        static let springImpact = SoundRecipe(
            modes: [
                .init(frequency: 240, amplitude: 1, decay: 0.04),
                .init(frequency: 520, amplitude: 0.4, decay: 0.025),
            ],
            noise: .init(amplitude: 0.35, decay: 0.004, brightness: 0.25),
            duration: 0.22,
            attack: 0.001,
            release: 0.02
        )
        /// The coil firing: a tone that wobbles and dies out.
        static let springBoing = SoundRecipe(
            modes: [
                .init(frequency: 220, amplitude: 1, decay: 0.28),
                .init(frequency: 440, amplitude: 0.3, decay: 0.18),
            ],
            noise: .init(amplitude: 0, decay: 0.001, brightness: 0),
            duration: 0.55,
            attack: 0.002,
            release: 0.06,
            wobble: .init(depth: 0.35, rate: 14, decay: 0.25)
        )
        /// A bright, short tink.
        static let glassImpact = SoundRecipe(
            modes: [
                .init(frequency: 2350, amplitude: 1, decay: 0.09),
                .init(frequency: 3720, amplitude: 0.5, decay: 0.06),
                .init(frequency: 5800, amplitude: 0.25, decay: 0.035),
            ],
            noise: .init(amplitude: 0.25, decay: 0.002, brightness: 0.8),
            duration: 0.3,
            attack: 0.0005,
            release: 0.03
        )
        /// Glass breaking: a bright crash with ringing fragments.
        static let glassShatter = SoundRecipe(
            modes: [
                .init(frequency: 3100, amplitude: 0.5, decay: 0.2),
                .init(frequency: 4650, amplitude: 0.4, decay: 0.14),
                .init(frequency: 5980, amplitude: 0.3, decay: 0.1),
                .init(frequency: 7340, amplitude: 0.2, decay: 0.07),
            ],
            noise: .init(amplitude: 1, decay: 0.09, brightness: 0.85),
            duration: 0.7,
            attack: 0.0005,
            release: 0.05
        )
        /// A small bell, for milestones and purchases.
        static let ding = SoundRecipe(
            modes: [
                .init(frequency: 880, amplitude: 1, decay: 0.32),
                .init(frequency: 1760, amplitude: 0.35, decay: 0.2),
                .init(frequency: 2640, amplitude: 0.15, decay: 0.12),
                .init(frequency: 3700, amplitude: 0.08, decay: 0.07),
            ],
            noise: .init(amplitude: 0.05, decay: 0.002, brightness: 0.7),
            duration: 0.8,
            attack: 0.001,
            release: 0.08
        )
        /// A deep swell when a piece is lost.
        static let lifeLost = SoundRecipe(
            modes: [
                .init(frequency: 98, amplitude: 1, decay: 0.35),
                .init(frequency: 196, amplitude: 0.5, decay: 0.25),
                .init(frequency: 294, amplitude: 0.2, decay: 0.15),
            ],
            noise: .init(amplitude: 0.1, decay: 0.03, brightness: 0.1),
            duration: 0.8,
            attack: 0.01,
            release: 0.1
        )
        /// A mellow, falling-away tone for the end of a game.
        static let gameOver = SoundRecipe(
            modes: [
                .init(frequency: 330, amplitude: 1, decay: 0.45),
                .init(frequency: 660, amplitude: 0.3, decay: 0.3),
                .init(frequency: 990, amplitude: 0.1, decay: 0.15),
            ],
            noise: .init(amplitude: 0.03, decay: 0.02, brightness: 0.1),
            duration: 1,
            attack: 0.01,
            release: 0.2
        )
        /// A bright, ringing clink of metal.
        static let goldImpact = SoundRecipe(
            modes: [
                .init(frequency: 1320, amplitude: 1, decay: 0.14),
                .init(frequency: 2960, amplitude: 0.45, decay: 0.09),
                .init(frequency: 4410, amplitude: 0.2, decay: 0.05),
            ],
            noise: .init(amplitude: 0.2, decay: 0.002, brightness: 0.7),
            duration: 0.4,
            attack: 0.0005,
            release: 0.04
        )
        /// A bird: a short high tweet that slides in pitch.
        static let chirp = SoundRecipe(
            modes: [
                .init(frequency: 3400, amplitude: 1, decay: 0.05),
                .init(frequency: 6800, amplitude: 0.2, decay: 0.03),
            ],
            noise: .init(amplitude: 0, decay: 0.001, brightness: 0),
            duration: 0.16,
            attack: 0.004,
            release: 0.03,
            wobble: .init(depth: 0.12, rate: 28, decay: 0.08)
        )
        /// A gust: muffled noise that swells and dies down.
        static let windGust = SoundRecipe(
            modes: [],
            noise: .init(amplitude: 1, decay: 2, brightness: 0.04),
            duration: 2.6,
            attack: 1.1,
            release: 1.4
        )
        /// A low, slowly pulsing hum while the tower leans. Loops seamlessly: every frequency fits a whole
        /// number of cycles in the duration.
        static let tensionDrone = SoundRecipe(
            modes: [
                .init(frequency: 55, amplitude: 1, decay: .infinity),
                .init(frequency: 56.5, amplitude: 0.8, decay: .infinity),
                .init(frequency: 110, amplitude: 0.25, decay: .infinity),
            ],
            noise: .init(amplitude: 0, decay: 0.001, brightness: 0),
            duration: 2,
            attack: 0,
            release: 0
        )
    }

    enum Guide {
        /// Screen points, constant whatever the zoom.
        static let lineWidth: CGFloat = 1.5
        static let lineOpacity: CGFloat = 0.28
        static let footprintHeight: CGFloat = 3
        static let footprintOpacity: CGFloat = 0.45
    }

    enum Look {
        /// Soft glowing motes drifting up through the sky, for a little magic in the background.
        static let moteSize: CGFloat = 18
        static let motesPerSecond: CGFloat = 1.8
        static let moteLifetime: CGFloat = 9
        static let moteRiseSpeed: CGFloat = 14
        static let moteOpacity: CGFloat = 0.75
        static let moteScale: CGFloat = 0.7
        static let blockCornerRadius: CGFloat = 0.2 * World.unit
        static let platformCornerRadius: CGFloat = 7
        /// Room around each block texture for its soft shadow.
        static let shadowPadding: CGFloat = 6
        static let shadowBlur: CGFloat = 4
        static let shadowOffset: CGFloat = 1.5
        /// Brightness difference between the top and the bottom of a block's gradient.
        static let gradientSpread: CGFloat = 0.07
        static let bevelHeight: CGFloat = 1.5
        static let bevelHighlightOpacity: CGFloat = 0.28
        static let bevelShadeOpacity: CGFloat = 0.12
        static let edgeDarkening: CGFloat = 0.22
        static let edgeWidth: CGFloat = 1
        /// Different speckle layouts per shape, so a tower of stones does not look copy-pasted.
        static let textureVariants = 3
        static let stoneSpecklesPerUnit: CGFloat = 9
        static let stoneSpeckleRadius: ClosedRange<CGFloat> = 0.7...1.8
        static let stoneSpeckleLightOpacity: CGFloat = 0.22
        static let stoneSpeckleDarkOpacity: CGFloat = 0.16
        /// Height of the small gradient textures stretched over the sky and the pillar.
        static let gradientTextureHeight: CGFloat = 128
        static let vanishDuration: TimeInterval = 0.3
        /// Overshoot of springy animations (a block popping in, a squash springing back). 0 = none.
        static let springOvershoot: Float = 1.4
        /// Spring: a zigzag coil across the block.
        static let coilTurnsPerUnit: CGFloat = 2.5
        static let coilLineWidth: CGFloat = 2
        static let coilAmplitude: CGFloat = 0.28
        static let coilOpacity: CGFloat = 0.55
        /// A spring that has fired is drawn faded.
        static let spentSpringFade: CGFloat = 0.35
        /// Glass: see-through body with diagonal glints.
        static let glassFillOpacity: CGFloat = 0.55
        static let glintSpacing: CGFloat = 14
        static let glintWidth: CGFloat = 3
        static let glintOpacity: CGFloat = 0.45
        /// Gold: a soft sheen band and small sparkles.
        static let sheenOpacity: CGFloat = 0.35
        static let sparklesPerUnit: CGFloat = 0.8
        static let sparkleSize: CGFloat = 3.5
        static let sparkleOpacity: CGFloat = 0.85
        /// Rounding of the inner (concave) corners of a piece.
        static let innerCornerRadius: CGFloat = 2
    }

    enum HUD {
        /// Size of one grid unit in the hand, so shapes keep their real proportions.
        static let previewUnit: CGFloat = 11
        static let cardSize: CGFloat = 54
        /// A drag must move this far before it picks the block up; shorter is a tap that selects it.
        static let dragThreshold: CGFloat = 4
    }

    enum Debug {
        /// Frame rate, node and draw counts in the corner.
        static let showsStatistics = false
        /// Draws physics bodies, handy to tune `Physics.bodyInset`.
        static let showsPhysicsOutlines = false
    }
}
