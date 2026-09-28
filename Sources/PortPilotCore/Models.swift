import Foundation

public struct ListeningPort: Identifiable, Hashable {
    public enum Proto: String { case tcp = "TCP", udp = "UDP" }

    public let port: Int
    public let proto: Proto
    /// true when the socket is bound only to 127.0.0.1 / ::1
    public var loopbackOnly: Bool

    public var id: String { "\(proto.rawValue)-\(port)" }

    public var hostLabel: String {
        if proto == .udp { return "UDP" }
        return loopbackOnly ? "localhost" : "all"
    }

    /// Ports that are almost never HTTP: no "open in browser" for these.
    private static let nonHTTP: Set<Int> = [22, 53, 1433, 2181, 3306, 5353, 5432, 5672, 6379, 9042, 9092, 11211, 27017]

    public var isLikelyHTTP: Bool { proto == .tcp && !Self.nonHTTP.contains(port) }
    public var url: URL? { URL(string: "http://localhost:\(port)") }
}

public struct PortProcess: Identifiable, Hashable {
    public enum Kind: Hashable { case dev, app, system }

    public let pid: pid_t
    public let command: String
    public let user: String
    public var executablePath: String?
    public var arguments: [String] = []
    public var workingDirectory: String?
    public var ports: [ListeningPort] = []

    public var displayName: String = ""
    public var projectHint: String?
    public var kind: Kind = .dev
    public var isCurrentUser: Bool = true

    public var id: pid_t { pid }

    public var subtitle: String {
        let origin = projectHint ?? executableName
        return isCurrentUser ? "\(origin), PID \(pid)" : "\(origin), PID \(pid), \(user)"
    }

    public var executableName: String {
        executablePath.map { ($0 as NSString).lastPathComponent } ?? command
    }

    public var fullCommandLine: String {
        arguments.isEmpty ? (executablePath ?? command) : arguments.joined(separator: " ")
    }

    /// Outermost bundle ("Visual Studio Code.app", not its "Code Helper.app"), except for
    /// toolchains inside Xcode, whose Python lives in Xcode.app/Contents/Developer/…/Python.app.
    public var appBundlePath: String? {
        guard let path = executablePath else { return nil }
        let options: String.CompareOptions = path.contains(".app/Contents/Developer/") ? .backwards : []
        guard let range = path.range(of: ".app/", options: options) else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }
}
