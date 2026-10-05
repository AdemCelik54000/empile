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

    /// Whether this install comes from the App Store. Anything unclear (Xcode, TestFlight, a receipt that
    /// cannot be verified) counts as a test build.
    static var isAppStoreBuild: Bool {
        get async {
            #if DEBUG
            false
            #else
            if case .verified(let transaction)? = try? await AppTransaction.shared {
                transaction.environment == .production
            } else {
                false
            }
            #endif
        }
    }
}
