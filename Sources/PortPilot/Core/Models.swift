import Foundation

struct ListeningPort: Identifiable, Hashable {
    enum Proto: String { case tcp = "TCP", udp = "UDP" }

    let port: Int
    let proto: Proto
    /// true when the socket is bound only to 127.0.0.1 / ::1
    var loopbackOnly: Bool

    var id: String { "\(proto.rawValue)-\(port)" }

    var hostLabel: String {
        if proto == .udp { return "UDP" }
        return loopbackOnly ? "localhost" : "all"
    }

    /// Ports that are almost never HTTP: no "open in browser" for these.
    private static let nonHTTP: Set<Int> = [22, 53, 1433, 2181, 3306, 5353, 5432, 5672, 6379, 9042, 9092, 11211, 27017]

    var isLikelyHTTP: Bool { proto == .tcp && !Self.nonHTTP.contains(port) }
    var url: URL? { URL(string: "http://localhost:\(port)") }
}

struct PortProcess: Identifiable, Hashable {
    enum Kind: Hashable { case dev, app, system }

    let pid: pid_t
    let command: String
    let user: String
    var executablePath: String?
    var arguments: [String] = []
    var ports: [ListeningPort] = []

    var displayName: String = ""
    var projectHint: String?
    var kind: Kind = .dev
    var isCurrentUser: Bool = true

    var id: pid_t { pid }

    var subtitle: String {
        let origin = projectHint ?? executableName
        return isCurrentUser ? "\(origin), PID \(pid)" : "\(origin), PID \(pid), \(user)"
    }

    var executableName: String {
        executablePath.map { ($0 as NSString).lastPathComponent } ?? command
    }

    var fullCommandLine: String {
        arguments.isEmpty ? (executablePath ?? command) : arguments.joined(separator: " ")
    }

    var appBundlePath: String? {
        guard let path = executablePath, let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }
}
