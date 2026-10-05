import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// Full-screen ads: one between games, and one the player may watch to continue a lost game. Asks for the
/// player's consent when the law requires it (the form comes from the AdMob account), starts the ad SDK, and
/// keeps one ad of each kind loaded, so showing it never makes the player wait. Knows nothing about when an
/// ad is due: see `AdSchedule`.
@MainActor
@Observable
final class AdManager: NSObject {
    /// An ad to continue a game is loaded and ready.
    private(set) var isRewardedReady = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var rewarded: RewardedAd?
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var isLoadingInterstitial = false
    @ObservationIgnored private var isLoadingRewarded = false
    /// The player watched the rewarded ad long enough to earn the reward.
    @ObservationIgnored private var didEarnReward = false
    /// Waits for the player to close the ad being shown.
    @ObservationIgnored private var closing: CheckedContinuation<Bool, Never>?

    /// Call once, when the app opens. Does nothing the second time.
    func start() async {
        guard Tuning.Ads.isEnabled, !isStarted else { return }
        isStarted = true
        await askForConsent()
        guard ConsentInformation.shared.canRequestAds else { return }
        await MobileAds.shared.start()
        await loadInterstitial()
        await loadRewarded()
    }

    /// Shows an ad if the player has finished enough games since the last one, and records it.
    func presentIfDue(_ settings: GameSettings) async {
        guard Tuning.Ads.isEnabled, settings.adSchedule.isDue, await present() else { return }
        settings.registerAdShown()
    }

    /// Shows the ready ad over the game, and waits until the player closes it.
    /// - Returns: Whether an ad was shown. `false` when none was ready (no network, nothing to serve, consent
    ///   refused): the game carries on and tries again at the next opportunity.
    func present() async -> Bool {
        guard let ad = interstitial, let controller = topViewController, closing == nil else {
            Task { await loadInterstitial() }
            return false
        }
        do {
            try ad.canPresent(from: controller)
        } catch {
            interstitial = nil
            Task { await loadInterstitial() }
            return false
        }
        interstitial = nil
        ad.fullScreenContentDelegate = self
        let wasShown = await withCheckedContinuation { continuation in
            closing = continuation
            ad.present(from: controller)
        }
        Task { await loadInterstitial() }
        return wasShown
    }

    /// Shows the ad that lets the player continue, and waits until it is closed.
    /// - Returns: Whether the player watched it long enough to earn the reward.
    func presentRewarded() async -> Bool {
        guard let ad = rewarded, let controller = topViewController, closing == nil else {
            Task { await loadRewarded() }
            return false
        }
        rewarded = nil
        isRewardedReady = false
        do {
            try ad.canPresent(from: controller)
        } catch {
            Task { await loadRewarded() }
            return false
        }
        didEarnReward = false
        ad.fullScreenContentDelegate = self
        let wasShown = await withCheckedContinuation { continuation in
            closing = continuation
            ad.present(from: controller) { [weak self] in
                self?.didEarnReward = true
            }
        }
        Task { await loadRewarded() }
        return wasShown && didEarnReward
    }

    private func loadInterstitial() async {
        guard isStarted, interstitial == nil, !isLoadingInterstitial, ConsentInformation.shared.canRequestAds
        else { return }
        isLoadingInterstitial = true
        defer { isLoadingInterstitial = false }
        interstitial = try? await InterstitialAd.load(with: await AdUnits.interstitialID(), request: Request())
    }

    private func loadRewarded() async {
        guard isStarted, rewarded == nil, !isLoadingRewarded, ConsentInformation.shared.canRequestAds,
              let unitID = await AdUnits.rewardedID()
        else { return }
        isLoadingRewarded = true
        defer { isLoadingRewarded = false }
        rewarded = try? await RewardedAd.load(with: unitID, request: Request())
        isRewardedReady = rewarded != nil
    }

    /// Shows the privacy message of the AdMob account when the player's country requires one.
    private func askForConsent() async {
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: topViewController)
        } catch {
            // No message set up or no network: `canRequestAds` tells whether ads may go on.
        }
    }

    private var topViewController: UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

extension AdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        closing?.resume(returning: true)
        closing = nil
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        closing?.resume(returning: false)
        closing = nil
    }
}
