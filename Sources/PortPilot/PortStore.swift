import PortPilotCore
import SwiftUI
import ServiceManagement

enum Prefs {
    static let showSystem = "showSystem"
    static let includeUDP = "includeUDP"
    static let confirmBeforeKill = "confirmBeforeKill"
    static let refreshInterval = "refreshInterval"
    static let theme = "theme"
    static let customAccent = "customAccent"
    static let mascot = "mascot"
    static let celebrate = "celebrate"
    static let animateMenuBar = "animateMenuBar"
    /// `PortPilot -demo YES`: fake processes for screenshots; quitting never signals anything.
    static let demo = "demo"

    static func register() {
        UserDefaults.standard.register(defaults: [
            showSystem: true,
            includeUDP: false,
            confirmBeforeKill: true,
            refreshInterval: 5.0,
            theme: Theme.system.id,
            customAccent: "",
            mascot: Mascot.cat.rawValue,
            celebrate: true,
            animateMenuBar: true
        ])
    }
}

@MainActor
final class PortStore: ObservableObject {
    @Published private(set) var processes: [PortProcess] = []
    @Published private(set) var busy: Set<pid_t> = []
    @Published private(set) var stubborn: Set<pid_t> = []
    @Published private(set) var messages: [pid_t: String] = [:]
    @Published private(set) var isRefreshing = false
    /// Bumped each time a quit succeeds, so the panel can cheer.
    @Published private(set) var celebrations = 0
    /// Frame of the menu bar mascot while it hops; nil shows the static symbol.
    @Published private(set) var menuBarFrame: Int?
    /// The one inline "Quit X?" confirmation currently shown, if any.
    @Published var pendingQuit: PendingQuit?

    struct PendingQuit: Equatable {
        let pid: pid_t
        let force: Bool
    }

    private var timer: Timer?
    private var hopTask: Task<Void, Never>?
    private var hasScanned = false

    init() {
        Prefs.register()
        startPolling()
        Task { await refresh() }
    }

    var devProcessCount: Int { processes.filter { $0.kind == .dev }.count }
    var portCount: Int { processes.reduce(0) { $0 + $1.ports.count } }

    /// Ports bound by more than one process (e.g. AirPlay Receiver and a .NET API both on TCP 5000).
    var clashingPorts: Set<ListeningPort.ID> {
        var owners: [ListeningPort.ID: Set<pid_t>] = [:]
        for p in processes {
            for port in p.ports { owners[port.id, default: []].insert(p.pid) }
        }
        return Set(owners.filter { $0.value.count > 1 }.keys)
    }

    func startPolling() {
        timer?.invalidate()
        let interval = max(2, UserDefaults.standard.double(forKey: Prefs.refreshInterval))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let result: [PortProcess]
        if UserDefaults.standard.bool(forKey: Prefs.demo) {
            result = hasScanned ? processes : PortScanner.demo()  // demo quits stick until relaunch
        } else {
            result = await PortScanner.scan(includeUDP: UserDefaults.standard.bool(forKey: Prefs.includeUDP))
        }
        let before = devProcessCount
        if result != processes { processes = result }  // no re-render when nothing changed
        if hasScanned && devProcessCount != before { hopMenuBar() }
        hasScanned = true
        let alive = Set(result.map(\.pid))
        stubborn = stubborn.intersection(alive)
        messages = messages.filter { alive.contains($0.key) }
        if let pid = pendingQuit?.pid, !alive.contains(pid) { pendingQuit = nil }
    }

    /// System and app processes always ask first; dev servers only if the setting says so.
    func requestQuit(_ process: PortProcess, force: Bool = false) {
        guard process.isCurrentUser else { return }
        if UserDefaults.standard.bool(forKey: Prefs.confirmBeforeKill) || process.kind != .dev {
            pendingQuit = PendingQuit(pid: process.pid, force: force)
        } else {
            Task { await terminate(process, force: force) }
        }
    }

    func confirmPendingQuit() {
        guard let pending = pendingQuit, let process = processes.first(where: { $0.pid == pending.pid }) else { return }
        pendingQuit = nil
        Task { await terminate(process, force: pending.force) }
    }

    func terminate(_ process: PortProcess, force: Bool = false) async {
        // Demo PIDs are made up and may belong to real processes: never send a signal.
        if UserDefaults.standard.bool(forKey: Prefs.demo) {
            processes.removeAll { $0.pid == process.pid }
            if UserDefaults.standard.bool(forKey: Prefs.celebrate) { celebrations += 1 }
            hopMenuBar()
            return
        }
        busy.insert(process.pid)
        let outcome = await ProcessKiller.terminate(process.pid, force: force)
        busy.remove(process.pid)

        switch outcome {
        case .terminated:
            stubborn.remove(process.pid)
            messages[process.pid] = nil
            if UserDefaults.standard.bool(forKey: Prefs.celebrate) { celebrations += 1 }
        case .notFound:
            stubborn.remove(process.pid)
            messages[process.pid] = nil
        case .stillRunning:
            stubborn.insert(process.pid)
            messages[process.pid] = String(localized: "\(process.displayName) is still running. Use Force Quit.")
        case .notPermitted:
            messages[process.pid] = String(localized: "Owned by another user. Quit it from Terminal with sudo.")
        case .failed(let code):
            messages[process.pid] = String(cString: strerror(code))
        }
        await refresh()
    }

    func terminateAllDevServers() async {
        let targets = processes.filter { $0.kind == .dev && $0.isCurrentUser }
        await withTaskGroup(of: Void.self) { group in
            for p in targets {
                group.addTask { await self.terminate(p) }
            }
        }
        await refresh()
    }

    /// Plays the mascot's hop in the menu bar for ~2 s: only when the dev server count changes, not on every poll.
    func hopMenuBar() {
        let mascot = Mascot(rawValue: UserDefaults.standard.string(forKey: Prefs.mascot) ?? "") ?? .cat
        let frames = mascot.menuBarFrames.count
        guard frames > 0, UserDefaults.standard.bool(forKey: Prefs.animateMenuBar),
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        hopTask?.cancel()
        hopTask = Task {
            for i in 0..<(frames * 2) {
                menuBarFrame = i % frames
                try? await Task.sleep(nanoseconds: 120_000_000)
                if Task.isCancelled { return }
            }
            menuBarFrame = nil
        }
    }

    // MARK: Launch at login (works once the app runs from a signed .app bundle)

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("PortPilot: launch at login failed: \(error.localizedDescription)")
            }
            objectWillChange.send()
        }
    }
}
