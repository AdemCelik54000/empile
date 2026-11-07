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
    /// Quand chaque pub prête a été chargée : passé `Tuning.Ads.adLifetime`, elle est remplacée (Google ne paie
    /// pas une pub expirée).
    @ObservationIgnored private var interstitialLoadedAt: Date?
    @ObservationIgnored private var rewardedLoadedAt: Date?
    /// Échecs de chargement d'affilée, pour espacer les nouvelles tentatives.
    @ObservationIgnored private var interstitialFailures = 0
    @ObservationIgnored private var rewardedFailures = 0
    /// Prochain chargement prévu (nouvelle tentative après un échec, ou remplacement d'une pub trop vieille).
    @ObservationIgnored private var interstitialReload: Task<Void, Never>?
    @ObservationIgnored private var rewardedReload: Task<Void, Never>?
    /// Fermeture de la dernière pub récompensée : aucune interstitielle ne la suit de trop près.
    @ObservationIgnored private var lastRewardedClose: Date?
    /// The player watched the rewarded ad long enough to earn the reward.
    @ObservationIgnored private var didEarnReward = false
    /// Waits for the player to close the ad being shown.
    @ObservationIgnored private var closing: CheckedContinuation<Bool, Never>?

    /// À appeler à l'ouverture de l'app, puis chaque fois que la connexion revient. Aucune pub n'est chargée
    /// avant d'avoir le statut de consentement. Si le consentement n'a pas pu être obtenu (pas de réseau au
    /// lancement, par exemple), un appel suivant réessaie au lieu de laisser la session sans pub.
    func start() async {
        guard Tuning.Ads.isEnabled, !isStarting else { return }
        // Origine de l'app (App Store, TestFlight, Xcode) vérifiée pendant le consentement, une fois par lancement.
        AdUnits.prepare()
        guard !isStarted else {
            // La demande de suivi a pu être repoussée (le joueur avait quitté l'accueil) : c'est le moment.
            await requestTrackingIfNeeded()
            // Retour à l'accueil ou de la connexion : une pub qui manque se recharge sans attendre.
            await loadInterstitial()
            await loadRewarded()
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
        let status = await MobileAds.shared.start()
        isStarted = true
        Self.log.info("Ad SDK started")
        // Médiation : un adaptateur « not ready » ne participe pas aux enchères (compte, ID ou SDK manquant).
        for (adapter, adapterStatus) in status.adapterStatusesByClassName.sorted(by: { $0.key < $1.key }) {
            let state = adapterStatus.state == .ready ? "ready" : "NOT ready"
            Self.log.info("Mediation adapter \(adapter, privacy: .public): \(state, privacy: .public) in \(adapterStatus.latency, format: .fixed(precision: 2), privacy: .public) s \(adapterStatus.description, privacy: .public)")
        }
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

    #if DEBUG
    /// L'inspecteur de pubs de Google (versions de développement seulement) : état de chaque adaptateur de
    /// médiation, et quel réseau a servi chaque pub, interstitielles comme récompensées.
    func presentAdInspector() {
        // La fin arrive hors du fil principal : journal local plutôt que celui de la classe.
        MobileAds.shared.presentAdInspector(from: topViewController) { error in
            guard let error = error as NSError? else { return }
            Logger(subsystem: "app.empile.Empile", category: "ads")
                .error("Ad inspector error: \(error.domain, privacy: .public) \(error.code, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
    #endif

    /// Shows an ad if the player has finished enough games since the last one, and records it.
    /// Jamais juste après une pub récompensée : le joueur vient d'en regarder une, l'interstitielle attend la
    /// prochaine fin de partie (le compteur n'est pas remis à zéro).
    func presentIfDue(_ settings: GameSettings) async {
        guard Tuning.Ads.isEnabled, settings.adSchedule.isDue else { return }
        if let closed = lastRewardedClose {
            let elapsed = Date().timeIntervalSince(closed)
            guard elapsed >= Tuning.Ads.interstitialPauseAfterRewarded else {
                Self.log.notice("Interstitial skipped: a rewarded ad closed \(Int(elapsed), privacy: .public) s ago, the next game over tries again")
                return
            }
        }
        guard await present() else { return }
        settings.registerAdShown()
    }

    /// Shows the ready ad over the game, and waits until the player closes it.
    /// - Returns: Whether an ad was shown. `false` when none was ready (no network, nothing to serve, consent
    ///   refused): the game carries on and tries again at the next opportunity.
    func present() async -> Bool {
        if interstitial != nil, !Self.isFresh(interstitialLoadedAt) {
            Self.log.notice("Interstitial expired before being shown: replaced")
            interstitial = nil
        }
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
        if rewarded != nil, !Self.isFresh(rewardedLoadedAt) {
            Self.log.notice("Rewarded ad expired before being shown: replaced")
            rewarded = nil
            isRewardedReady = false
        }
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
        if wasShown { lastRewardedClose = Date() }
        Task { await loadRewarded() }
        return wasShown && didEarnReward
    }

    private func loadInterstitial() async {
        guard isStarted, interstitial == nil, !isLoadingInterstitial, ConsentInformation.shared.canRequestAds
        else { return }
        isLoadingInterstitial = true
        defer { isLoadingInterstitial = false }
        let unitID = await AdUnits.interstitialID()
        let reason = await AdUnits.origin.reason
        Self.log.info("Loading interstitial, unit \(unitID, privacy: .public) (\(Self.kind(of: unitID), privacy: .public), because \(reason, privacy: .public))")
        do {
            interstitial = try await InterstitialAd.load(with: unitID, request: Request())
            interstitialLoadedAt = Date()
            interstitialFailures = 0
            Self.log.info("Interstitial loaded")
            // Remplacée avant d'expirer, si elle n'a pas été montrée d'ici là.
            scheduleInterstitialReload(after: Tuning.Ads.adLifetime)
        } catch {
            interstitial = nil
            interstitialFailures += 1
            let delay = Self.retryDelay(afterFailures: interstitialFailures)
            Self.log.error("Interstitial failed to load: \(Self.describe(error), privacy: .public), next try in \(Int(delay), privacy: .public) s")
            scheduleInterstitialReload(after: delay)
        }
    }

    private func scheduleInterstitialReload(after delay: TimeInterval) {
        interstitialReload?.cancel()
        interstitialReload = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self else { return }
            if interstitial != nil, !Self.isFresh(interstitialLoadedAt) {
                Self.log.info("Interstitial kept too long: replaced")
                interstitial = nil
            }
            await loadInterstitial()
        }
    }

    private func loadRewarded() async {
        guard isStarted, rewarded == nil, !isLoadingRewarded, ConsentInformation.shared.canRequestAds,
              let unitID = await AdUnits.rewardedID()
        else { return }
        isLoadingRewarded = true
        defer { isLoadingRewarded = false }
        let reason = await AdUnits.origin.reason
        Self.log.info("Loading rewarded ad, unit \(unitID, privacy: .public) (\(Self.kind(of: unitID), privacy: .public), because \(reason, privacy: .public))")
        do {
            rewarded = try await RewardedAd.load(with: unitID, request: Request())
            rewardedLoadedAt = Date()
            rewardedFailures = 0
            Self.log.info("Rewarded ad loaded")
            scheduleRewardedReload(after: Tuning.Ads.adLifetime)
        } catch {
            // Avant, rien ne la rechargeait : son bouton restait grisé, donc jamais touché, pour toute la session.
            rewarded = nil
            rewardedFailures += 1
            let delay = Self.retryDelay(afterFailures: rewardedFailures)
            Self.log.error("Rewarded ad failed to load: \(Self.describe(error), privacy: .public), next try in \(Int(delay), privacy: .public) s")
            scheduleRewardedReload(after: delay)
        }
        isRewardedReady = rewarded != nil
    }

    private func scheduleRewardedReload(after delay: TimeInterval) {
        rewardedReload?.cancel()
        rewardedReload = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self else { return }
            if rewarded != nil, !Self.isFresh(rewardedLoadedAt) {
                Self.log.info("Rewarded ad kept too long: replaced")
                rewarded = nil
                isRewardedReady = false
            }
            await loadRewarded()
        }
    }

    /// Une pub chargée depuis moins de `Tuning.Ads.adLifetime` peut encore être montrée.
    private static func isFresh(_ loadedAt: Date?) -> Bool {
        guard let loadedAt else { return false }
        return Date().timeIntervalSince(loadedAt) < Tuning.Ads.adLifetime
    }

    /// Attente avant de réessayer : doublée à chaque échec d'affilée, plafonnée, pour ne pas inonder le réseau
    /// publicitaire de requêtes sans réponse (ce qui fait baisser le taux de remplissage).
    private static func retryDelay(afterFailures failures: Int) -> TimeInterval {
        let doubled = Tuning.Ads.firstRetryDelay * pow(2, Double(max(0, failures - 1)))
        return min(doubled, Tuning.Ads.maxRetryDelay)
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
