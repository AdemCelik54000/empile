import AppTrackingTransparency
import GoogleMobileAds
import Observation
import OSLog
import UIKit
import UserMessagingPlatform

/// Full-screen ads: one between games, and one the player may watch to continue a lost game. Asks for the
/// player's consent when the law requires it (the form comes from the AdMob account), starts the ad SDK, and
/// keeps one ad of each kind loaded, so showing it never makes the player wait. Knows nothing about when an
/// ad is due: see `AdSchedule`.
@MainActor
@Observable
final class AdManager: NSObject {
    /// Why an ad did or did not appear: read it in Xcode's console or the Mac's Console app
    /// (subsystem `app.empile.Empile`, category `ads`).
    private static let log = Logger(subsystem: "app.empile.Empile", category: "ads")

    /// An ad to continue a game is loaded and ready.
    private(set) var isRewardedReady = false
    /// Le formulaire de consentement exige un bouton « Gérer mes choix de confidentialité » (cas de l'Europe) :
    /// les réglages l'affichent seulement quand c'est vrai.
    private(set) var isPrivacyOptionsRequired = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var rewarded: RewardedAd?
    @ObservationIgnored private var isStarted = false
    /// Un démarrage (consentement puis SDK) est en cours : un second appel ne le double pas.
    @ObservationIgnored private var isStarting = false
    /// Mis à jour par l'écran racine : vrai seulement sur l'accueil, quand rien ne bloque l'accès au jeu. Le
    /// formulaire de consentement n'apparaît jamais sinon (le joueur a pu lancer une partie pendant que le
    /// statut se chargeait) : il attend le prochain retour à l'accueil.
    @ObservationIgnored var canInterruptPlayer = false
    @ObservationIgnored private var isLoadingInterstitial = false
    @ObservationIgnored private var isLoadingRewarded = false
    /// The player watched the rewarded ad long enough to earn the reward.
    @ObservationIgnored private var didEarnReward = false
    /// Waits for the player to close the ad being shown.
    @ObservationIgnored private var closing: CheckedContinuation<Bool, Never>?

    /// À appeler à l'ouverture de l'app, puis chaque fois que la connexion revient. Aucune pub n'est chargée
    /// avant d'avoir le statut de consentement. Si le consentement n'a pas pu être obtenu (pas de réseau au
    /// lancement, par exemple), un appel suivant réessaie au lieu de laisser la session sans pub.
    func start() async {
        guard Tuning.Ads.isEnabled, !isStarting else { return }
        guard !isStarted else {
            // La demande de suivi a pu être repoussée (le joueur avait quitté l'accueil) : c'est le moment.
            await requestTrackingIfNeeded()
            return
        }
        isStarting = true
        defer { isStarting = false }
        await askForConsent()
        let canRequestAds = ConsentInformation.shared.canRequestAds
        Self.log.info("Consent: status \(Self.describe(ConsentInformation.shared.consentStatus), privacy: .public), canRequestAds \(canRequestAds, privacy: .public)")
        guard canRequestAds else {
            Self.log.notice("No ad will load for now: consent does not allow requesting ads (tried again when the connection returns)")
            return
        }
        // Après le consentement UMP et avant la première requête, pour que celle-ci profite déjà de la réponse.
        await requestTrackingIfNeeded()
        await MobileAds.shared.start()
        isStarted = true
        Self.log.info("Ad SDK started")
        await loadInterstitial()
        await loadRewarded()
    }

    /// Rouvre le formulaire de consentement, depuis les réglages, pour que le joueur change ses choix.
    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: topViewController)
        } catch {
            Self.log.error("Privacy options form error: \(Self.describe(error), privacy: .public)")
        }
        updatePrivacyOptionsRequirement()
        // Le joueur a pu accepter maintenant ce qu'il avait refusé : les pubs peuvent démarrer.
        await start()
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
            Self.log.notice("Interstitial not shown: ad ready \(self.interstitial != nil, privacy: .public), screen available \(self.topViewController != nil, privacy: .public), another ad open \(self.closing != nil, privacy: .public)")
            Task { await loadInterstitial() }
            return false
        }
        do {
            try ad.canPresent(from: controller)
        } catch {
            Self.log.error("Interstitial cannot be presented: \(error.localizedDescription, privacy: .public)")
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
            Self.log.notice("Rewarded ad not shown: ad ready \(self.rewarded != nil, privacy: .public), screen available \(self.topViewController != nil, privacy: .public), another ad open \(self.closing != nil, privacy: .public)")
            Task { await loadRewarded() }
            return false
        }
        rewarded = nil
        isRewardedReady = false
        do {
            try ad.canPresent(from: controller)
        } catch {
            Self.log.error("Rewarded ad cannot be presented: \(error.localizedDescription, privacy: .public)")
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
        let unitID = await AdUnits.interstitialID()
        Self.log.info("Loading interstitial, unit \(unitID, privacy: .public) (\(Self.kind(of: unitID), privacy: .public))")
        do {
            interstitial = try await InterstitialAd.load(with: unitID, request: Request())
            Self.log.info("Interstitial loaded")
        } catch {
            interstitial = nil
            Self.log.error("Interstitial failed to load: \(Self.describe(error), privacy: .public)")
        }
    }

    private func loadRewarded() async {
        guard isStarted, rewarded == nil, !isLoadingRewarded, ConsentInformation.shared.canRequestAds,
              let unitID = await AdUnits.rewardedID()
        else { return }
        isLoadingRewarded = true
        defer { isLoadingRewarded = false }
        Self.log.info("Loading rewarded ad, unit \(unitID, privacy: .public) (\(Self.kind(of: unitID), privacy: .public))")
        do {
            rewarded = try await RewardedAd.load(with: unitID, request: Request())
            Self.log.info("Rewarded ad loaded")
        } catch {
            rewarded = nil
            Self.log.error("Rewarded ad failed to load: \(Self.describe(error), privacy: .public)")
        }
        isRewardedReady = rewarded != nil
    }

    /// Shows the privacy message of the AdMob account when the player's country requires one.
    private func askForConsent() async {
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            if canInterruptPlayer {
                try await ConsentForm.loadAndPresentIfRequired(from: topViewController)
            } else {
                Self.log.notice("Consent form postponed: the player left the home screen")
            }
        } catch {
            // No message set up or no network: `canRequestAds` tells whether ads may go on.
            Self.log.error("Consent form error: \(Self.describe(error), privacy: .public)")
        }
        updatePrivacyOptionsRequirement()
    }

    /// Demande d'App Tracking Transparency : une seule fois dans la vie de l'app (iOS ne la montre plus ensuite),
    /// toujours après le consentement UMP, jamais au lancement ni pendant une partie. Si le message de
    /// consentement AdMob contient déjà l'explication IDFA, UMP a posé la question et rien ne se passe ici.
    /// Un refus ne change rien au jeu : les pubs continuent, simplement moins ciblées.
    private func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // Hors premier plan, iOS peut répondre « refusé » sans rien montrer : la seule question serait perdue.
        guard canInterruptPlayer, UIApplication.shared.applicationState == .active else {
            Self.log.notice("Tracking request postponed: the player is not on the home screen")
            return
        }
        let status = await ATTrackingManager.requestTrackingAuthorization()
        Self.log.info("Tracking authorization: \(Self.describe(status), privacy: .public)")
    }

    private func updatePrivacyOptionsRequirement() {
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private static func kind(of unitID: String) -> String {
        let isTest = unitID == Tuning.Ads.testInterstitialUnitID || unitID == Tuning.Ads.testRewardedUnitID
        return isTest ? "Google test unit" : "REAL unit"
    }

    private static func describe(_ status: ConsentStatus) -> String {
        switch status {
        case .unknown: "unknown"
        case .required: "required"
        case .notRequired: "not required"
        case .obtained: "obtained"
        @unknown default: "other"
        }
    }

    private static func describe(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "not determined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorized: "authorized"
        @unknown default: "other"
        }
    }

    /// The error's domain and code as well as its text: Google's codes tell "no fill" from "bad unit ID".
    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
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
        Self.log.error("Ad failed to present: \(Self.describe(error), privacy: .public)")
        closing?.resume(returning: false)
        closing = nil
    }
}
