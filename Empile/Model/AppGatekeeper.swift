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

/// Asks the App Store which version of the game is published, and remembers it when it is newer than this one.
@MainActor
@Observable
final class UpdateChecker {
    /// Set when the player must update before playing.
    private(set) var requiredUpdate: AppStoreRelease?
    @ObservationIgnored private var isChecking = false

    private static var installedVersion: AppVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
    }

    /// Any failure (no network, game not published yet, unreadable answer) lets the player in.
    func check() async {
        guard !isChecking, let bundleID = Bundle.main.bundleIdentifier else { return }
        isChecking = true
        defer { isChecking = false }
        guard let release = await Self.fetchRelease(bundleID: bundleID).map(Self.debugOverride) else { return }
        requiredUpdate = release.isNewer(than: Self.installedVersion) ? release : nil
    }

    /// In debug builds, `-EmpileDebugStoreVersion 99.0` pretends the store has that version, to see the update screen.
    private static func debugOverride(_ release: AppStoreRelease) -> AppStoreRelease {
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: "EmpileDebugStoreVersion").flatMap(AppVersion.init) {
            return AppStoreRelease(version: forced, trackID: release.trackID)
        }
        #endif
        return release
    }

    private static func fetchRelease(bundleID: String) async -> AppStoreRelease? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: "fr"),
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return AppStoreRelease(lookupResponse: data)
    }
}
