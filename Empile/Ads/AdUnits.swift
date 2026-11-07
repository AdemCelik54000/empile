import OSLog
import StoreKit

/// Which ad unit to use. Debug builds always get Google's test ads. In Release, test ads only when the app is
/// positively known to come from TestFlight or Xcode, so nobody on the team ever clicks a real ad (which Google
/// treats as fraud). Anything uncertain gets the real unit: a player from the App Store must never see test
/// ads, which earn nothing.
enum AdUnits {
    static func interstitialID() async -> String {
        await isAppStoreBuild ? Tuning.Ads.liveInterstitialUnitID : Tuning.Ads.testInterstitialUnitID
    }

    /// `nil` in the App Store version until the AdMob account has a rewarded unit.
    static func rewardedID() async -> String? {
        await isAppStoreBuild ? Tuning.Ads.liveRewardedUnitID : Tuning.Ads.testRewardedUnitID
    }

    /// Ce que la vérification a conclu, et pourquoi : la raison accompagne chaque log de chargement.
    struct Origin: Sendable {
        let isAppStore: Bool
        let reason: String
    }

    static var isAppStoreBuild: Bool {
        get async { await origin.isAppStore }
    }

    static var origin: Origin {
        get async { await check.value }
    }

    /// À appeler au lancement : lance la vérification sans attendre son résultat.
    static func prepare() {
        _ = check
    }

    private static let log = Logger(subsystem: "app.empile.Empile", category: "ads")

    /// Faite une seule fois par lancement : la première demande la démarre, les suivantes attendent ce même
    /// résultat au lieu d'interroger StoreKit à chaque chargement de pub.
    private static let check = Task { () -> Origin in
        let origin = await detectOrigin()
        log.info("Ad units: \(origin.isAppStore ? "REAL unit" : "Google test unit", privacy: .public) for this launch (\(origin.reason, privacy: .public))")
        return origin
    }

    private static func detectOrigin() async -> Origin {
        #if DEBUG
        return Origin(isAppStore: false, reason: "debug build")
        #else
        do {
            switch try await AppTransaction.shared {
            case .verified(let transaction):
                return origin(of: transaction.environment)
            case .unverified(let transaction, let error):
                // Signature invalide : l'environnement annoncé n'est pas fiable, donc incertain, donc vraies pubs.
                return Origin(isAppStore: true, reason: "AppTransaction not verified (\(error.localizedDescription)), claims \(transaction.environment.rawValue): real unit by default")
            }
        } catch {
            let nsError = error as NSError
            return Origin(isAppStore: true, reason: "AppTransaction unavailable (\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)): real unit by default")
        }
        #endif
    }

    /// Seuls TestFlight (sandbox) et Xcode donnent les pubs de test ; tout autre environnement, connu ou non,
    /// est traité comme l'App Store.
    private static func origin(of environment: AppStore.Environment) -> Origin {
        switch environment {
        case .production:
            Origin(isAppStore: true, reason: "AppTransaction verified: App Store")
        case .sandbox:
            Origin(isAppStore: false, reason: "AppTransaction verified: TestFlight (sandbox)")
        case .xcode:
            Origin(isAppStore: false, reason: "AppTransaction verified: Xcode")
        default:
            Origin(isAppStore: true, reason: "AppTransaction verified, unknown environment \(environment.rawValue): real unit by default")
        }
    }
}
