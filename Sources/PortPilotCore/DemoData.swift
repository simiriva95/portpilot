import Foundation

extension PortScanner {
    /// Fake but realistic processes for screenshots and UI work (`PortPilot -demo YES`).
    /// Classified by the real DevDetector, so names, projects and kinds match a live scan.
    public static func demo() -> [PortProcess] {
        let me = NSUserName()
        func process(_ pid: pid_t, _ exe: String, _ args: [String], cwd: String? = nil, user: String? = nil,
                     _ ports: [(Int, Bool)]) -> PortProcess {
            var p = PortProcess(pid: pid, command: (exe as NSString).lastPathComponent, user: user ?? me)
            p.executablePath = exe
            p.arguments = args
            p.workingDirectory = cwd
            p.ports = ports.map { ListeningPort(port: $0.0, proto: .tcp, loopbackOnly: $0.1) }
            p.isCurrentUser = p.user == me
            DevDetector.classify(&p)
            return p
        }
        let node = "/opt/homebrew/bin/node"
        return [
            process(48211, node, ["node", "/Users/dev/code/frontend-admin/node_modules/.bin/vite"], [(5173, true)]),
            process(48342, node, ["next-server (v14.2.3)"], cwd: "/Users/dev/code/shop", [(3000, false)]),
            process(51007, "/usr/local/share/dotnet/dotnet", ["dotnet", "bin/Debug/net8.0/OrdersApi.dll"],
                    cwd: "/Users/dev/code/orders-service", [(5000, true), (5001, true)]),
            process(48790, node, ["node", "/Users/dev/code/design-system/node_modules/.bin/storybook", "dev"], [(6006, false)]),
            process(612, "/opt/homebrew/opt/postgresql@16/bin/postgres", ["postgres", "-D", "/opt/homebrew/var/postgresql@16"],
                    [(5432, true)]),
            process(640, "/opt/homebrew/bin/redis-server", ["redis-server", "127.0.0.1:6379"], [(6379, true)]),
            process(733, "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter",
                    ["ControlCenter"], [(5000, false), (7000, false)]),
            process(1, "/sbin/launchd", ["launchd"], user: "root", [(22, false)]),
        ]
        .sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind == .dev || (lhs.kind == .app && rhs.kind == .system) }
            return (lhs.ports.first?.port ?? 0) < (rhs.ports.first?.port ?? 0)
        }
    }
}
