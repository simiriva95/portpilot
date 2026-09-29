import AppKit
import PortPilotCore

/// Checks GitHub Releases once a day and installs updates in place: download the zip, verify it against
/// the release's SHA256SUMS.txt, check it's PortPilot at the expected version, then do what the manual
/// install guide does (drop the quarantine flag, sign ad hoc), swap the bundle and relaunch.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle, checking, upToDate
        case available(Release)
        case installing(Release)
        case failed(String, page: URL?)
    }

    @Published private(set) var state: State = .idle

    /// nil outside an app bundle (`swift run`), where there's nothing to replace.
    let currentVersion: String? = Bundle.main.bundleURL.pathExtension == "app"
        ? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String : nil

    private var timer: Timer?

    init() {
        guard currentVersion != nil else { return }
        Task { await checkIfDue() }
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.checkIfDue() }
        }
    }

    private func checkIfDue() async {
        let last = UserDefaults.standard.double(forKey: Prefs.lastUpdateCheck)
        guard UserDefaults.standard.bool(forKey: Prefs.checkForUpdates),
              Date().timeIntervalSince1970 - last > 86_400 else { return }
        await check(userInitiated: false)
    }

    /// Background checks fail silently; a check from Settings reports the error.
    func check(userInitiated: Bool) async {
        guard let current = currentVersion else { return }
        switch state {
        case .checking, .installing: return
        default: break
        }
        state = .checking
        do {
            var request = URLRequest(url: Update.latestURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure(String(localized: "GitHub didn't return the latest release.")) }
            let release = try JSONDecoder().decode(Release.self, from: data)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Prefs.lastUpdateCheck)
            state = Update.isNewer(release.version, than: current) ? .available(release) : .upToDate
        } catch {
            state = userInitiated ? .failed(error.localizedDescription, page: nil) : .idle
        }
    }

    func install(_ release: Release) async {
        state = .installing(release)
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("PortPilot-update-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }
        do {
            let app = try await Self.prepare(release, in: work)
            // The running bundle can be replaced: macOS keeps the old executable mapped until we quit.
            _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: app)
            try? FileManager.default.removeItem(at: work)  // relaunch quits before defer runs
            Self.relaunch()
        } catch {
            state = .failed(error.localizedDescription, page: release.page)
        }
    }

    // MARK: Steps (off the main actor)

    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    /// Downloads, verifies and unpacks the update; returns the new PortPilot.app, ready to swap in.
    nonisolated private static func prepare(_ release: Release, in work: URL) async throws -> URL {
        guard let zip = release.zip, let sums = release.checksums, Update.isTrusted(zip.url), Update.isTrusted(sums.url) else {
            throw Failure(String(localized: "This release has no verifiable download."))
        }
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)

        let sumsFile = try await download(sums.url, into: work)
        let zipFile = try await download(zip.url, into: work)
        guard let expected = Update.checksum(for: zip.name, in: try String(contentsOf: sumsFile, encoding: .utf8)),
              try Update.sha256(of: zipFile) == expected else {
            throw Failure(String(localized: "The download doesn't match its checksum, so it wasn't installed."))
        }

        try run("/usr/bin/ditto", ["-x", "-k", zipFile.path, work.path])
        let app = work.appendingPathComponent("PortPilot.app")
        guard let info = Bundle(url: app)?.infoDictionary,
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == release.version else {
            throw Failure(String(localized: "The download is not PortPilot \(release.version)."))
        }
        // Same as the manual install guide. xattr fails when there's no flag to remove, which is fine.
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", app.path])
        try run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", app.path])
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        return app
    }

    /// URLSession's download file is deleted when the task ends, so move it into our work folder.
    nonisolated private static func download(_ url: URL, into work: URL) async throws -> URL {
        let (temp, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure(String(localized: "The update couldn't be downloaded."))
        }
        let file = work.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: temp, to: file)
        return file
    }

    nonisolated private static func run(_ tool: String, _ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure(String(localized: "\((tool as NSString).lastPathComponent) failed while installing the update."))
        }
    }

    /// Reopens the app once this process has exited. PID and path go in as arguments, never into the script.
    private static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"",
                             "sh", String(getpid()), Bundle.main.bundleURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }
}
