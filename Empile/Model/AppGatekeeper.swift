import Foundation
import Network
import Observation

/// Follows the device's connection for the whole app life: the game needs the Internet to serve its ads.
@MainActor
@Observable
final class ConnectivityMonitor {
    /// Assumed true until the system says otherwise, so the home screen does not flash a warning at launch.
    private(set) var isOnline = true
    @ObservationIgnored private var monitor: NWPathMonitor?

    /// Call once, when the app opens. Updates keep coming until the app quits.
    func start() {
        guard monitor == nil else { return }
        #if DEBUG
        // `-EmpileDebugOffline YES` shows the offline screen without cutting the network.
        if UserDefaults.standard.bool(forKey: "EmpileDebugOffline") {
            isOnline = false
            return
        }
        #endif
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in self?.isOnline = isOnline }
        }
        monitor.start(queue: DispatchQueue(label: "app.empile.connectivity"))
        self.monitor = monitor
    }
}

/// Lit la version minimale exigée dans un petit fichier du site du jeu, et la retient quand celle installée est
/// plus ancienne. Le fichier, pas l'App Store, décide : on n'y monte le chiffre qu'une fois la nouvelle version
/// proposée partout, donc aucun joueur n'est bloqué devant un App Store qui n'a encore rien de neuf à lui donner.
@MainActor
@Observable
final class UpdateChecker {
    /// Set when the player must update before playing.
    private(set) var requiredUpdate: RequiredUpdate?
    /// Vrai dès que la première vérification a abouti ou échoué : avant, l'accueil attend un peu pour lancer une
    /// partie, sinon un joueur rapide entrerait dans une partie (jamais coupée) avec une version périmée.
    @ObservationIgnored private(set) var isFirstCheckDone = false
    @ObservationIgnored private var isChecking = false

    /// Au plus ce délai d'attente au premier « Jouer » : un site qui ne répond pas ne bloque jamais le jeu.
    static let firstCheckWait: Duration = .seconds(3)
    /// Le fichier `empile-version.json` du dépôt `ademcelik54000.github.io`, par exemple
    /// `{ "minimumVersion": "1.26" }`. GitHub Pages le garde jusqu'à 10 minutes en cache.
    static let versionFileURL = URL(string: "https://ademcelik54000.github.io/empile-version.json")!

    private static var installedVersion: AppVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
    }

    /// Tout échec (pas de réseau, fichier absent ou illisible) laisse jouer : on ne bloque que sur une vraie réponse.
    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer {
            isChecking = false
            isFirstCheckDone = true
        }
        guard let minimum = Self.debugOverride(await Self.fetchRequirement()) else { return }
        requiredUpdate = minimum.isRequired(for: Self.installedVersion) ? minimum : nil
    }

    /// Rend la main quand la première vérification est finie, ou au bout de `limit` si elle traîne.
    func waitForFirstCheck(upTo limit: Duration = firstCheckWait) async {
        let clock = ContinuousClock()
        let deadline = clock.now + limit
        while !isFirstCheckDone, clock.now < deadline {
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        }
    }

    /// En debug, `-EmpileDebugMinimumVersion 99.0` fait comme si le fichier exigeait cette version, pour voir
    /// l'écran de mise à jour, même si le fichier n'a pas pu être lu.
    private static func debugOverride(_ requirement: RequiredUpdate?) -> RequiredUpdate? {
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: "EmpileDebugMinimumVersion").flatMap(AppVersion.init) {
            return RequiredUpdate(minimumVersion: forced)
        }
        #endif
        return requirement
    }

    private static func fetchRequirement() async -> RequiredUpdate? {
        let request = URLRequest(url: versionFileURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return RequiredUpdate(versionFile: data)
    }
}
