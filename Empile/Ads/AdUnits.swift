import OSLog
import StoreKit

/// Which ad unit to use: real ads only in the version downloaded from the App Store. Xcode builds, TestFlight
/// and any other install get Google's test ads, so nobody on the team ever sees or clicks a real ad (which
/// Google treats as fraud and can punish by closing the account).
enum AdUnits {
    static func interstitialID() async -> String {
        await isAppStoreBuild ? Tuning.Ads.liveInterstitialUnitID : Tuning.Ads.testInterstitialUnitID
    }

    /// `nil` in the App Store version until the AdMob account has a rewarded unit.
    static func rewardedID() async -> String? {
        await isAppStoreBuild ? Tuning.Ads.liveRewardedUnitID : Tuning.Ads.testRewardedUnitID
    }

    private static let log = Logger(subsystem: "app.empile.Empile", category: "ads")

    /// Whether this install comes from the App Store. Anything unclear (Xcode, TestFlight, a receipt that
    /// cannot be verified) counts as a test build. The reason is written to the log.
    static var isAppStoreBuild: Bool {
        get async {
            #if DEBUG
            log.info("AppTransaction not checked: debug build, Google test ads")
            return false
            #else
            do {
                switch try await AppTransaction.shared {
                case .verified(let transaction):
                    let isProduction = transaction.environment == .production
                    log.info("AppTransaction verified, environment \(transaction.environment.rawValue, privacy: .public): \(isProduction ? "App Store build, real ads" : "not the App Store, Google test ads", privacy: .public)")
                    return isProduction
                case .unverified(_, let error):
                    log.error("AppTransaction NOT verified (\(error.localizedDescription, privacy: .public)): Google test ads")
                    return false
                }
            } catch {
                let nsError = error as NSError
                log.error("AppTransaction unavailable (\(nsError.domain, privacy: .public) \(nsError.code, privacy: .public): \(nsError.localizedDescription, privacy: .public)): Google test ads")
                return false
            }
            #endif
        }
    }
}
