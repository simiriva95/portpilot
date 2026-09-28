import SwiftUI
import ServiceManagement

enum Prefs {
    static let showSystem = "showSystem"
    static let includeUDP = "includeUDP"
    static let confirmBeforeKill = "confirmBeforeKill"
    static let refreshInterval = "refreshInterval"

    static func register() {
        UserDefaults.standard.register(defaults: [
            showSystem: true,
            includeUDP: false,
            confirmBeforeKill: true,
            refreshInterval: 5.0
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

    private var timer: Timer?

    init() {
        Prefs.register()
        startPolling()
        Task { await refresh() }
    }

    var devProcessCount: Int { processes.filter { $0.kind == .dev }.count }
    var portCount: Int { processes.reduce(0) { $0 + $1.ports.count } }

    /// Port numbers bound by more than one process (e.g. AirPlay Receiver and a .NET API both on 5000).
    var clashingPorts: Set<Int> {
        var owners: [Int: Set<pid_t>] = [:]
        for p in processes {
            for port in p.ports { owners[port.port, default: []].insert(p.pid) }
        }
        return Set(owners.filter { $0.value.count > 1 }.keys)
    }

    func startPolling() {
        timer?.invalidate()
        let interval = max(2, UserDefaults.standard.double(forKey: Prefs.refreshInterval))
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let result = await PortScanner.scan(includeUDP: UserDefaults.standard.bool(forKey: Prefs.includeUDP))
        processes = result
        let alive = Set(result.map(\.pid))
        stubborn = stubborn.intersection(alive)
        messages = messages.filter { alive.contains($0.key) }
    }

    func terminate(_ process: PortProcess, force: Bool = false) async {
        busy.insert(process.pid)
        let outcome = await ProcessKiller.terminate(process.pid, force: force)
        busy.remove(process.pid)

        switch outcome {
        case .terminated, .notFound:
            stubborn.remove(process.pid)
            messages[process.pid] = nil
        case .stillRunning:
            stubborn.insert(process.pid)
            messages[process.pid] = "\(process.displayName) is still running. Use Force Quit."
        case .notPermitted:
            messages[process.pid] = "Owned by another user. Quit it from Terminal with sudo."
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
