import Foundation

/// Reads listening sockets with `lsof` and `netstat` and enriches each process with its
/// executable path, arguments and a friendly name.
public enum PortScanner {
    public static func scan(includeUDP: Bool) async -> [PortProcess] {
        await Task.detached(priority: .utility) { PortScanner.scanSync(includeUDP: includeUDP) }.value
    }

    static func scanSync(includeUDP: Bool) -> [PortProcess] {
        // -F emits machine-readable fields: p=pid c=command L=login P=protocol n=name
        var args = ["-nP", "-iTCP", "-sTCP:LISTEN"]
        if includeUDP { args.append("-iUDP") }
        args.append("-FpcLPn")
        var processes = Shell.run("/usr/sbin/lsof", args).map(parse(output:)) ?? []

        // Without root, lsof can't see processes of other users (and skips a few of ours); netstat can.
        let seen = Set(processes.map(\.pid))
        if let output = Shell.run("/usr/sbin/netstat", ["-anv", "-p", "tcp"]) {
            processes += parseNetstat(output: output).filter { !seen.contains($0.pid) }
        }

        let me = NSUserName()
        return processes
            .map { raw -> PortProcess in
                var p = raw
                if let info = ProcInfo.arguments(of: p.pid) {
                    p.executablePath = info.path
                    p.arguments = info.args
                } else {
                    p.executablePath = ProcInfo.path(of: p.pid)
                }
                p.workingDirectory = ProcInfo.workingDirectory(of: p.pid)
                p.isCurrentUser = p.user == me
                DevDetector.classify(&p)
                return p
            }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return rank(lhs.kind) < rank(rhs.kind) }
                return (lhs.ports.first?.port ?? 0) < (rhs.ports.first?.port ?? 0)
            }
    }

    /// Groups `lsof -F` output by process, in lsof order, with ports sorted and IPv4/IPv6 duplicates merged.
    static func parse(output: String) -> [PortProcess] {
        var groups = Grouper()
        var pid: pid_t = 0
        var command = ""
        var user = ""
        var proto = ListeningPort.Proto.tcp

        for line in output.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p": pid = pid_t(value) ?? 0; command = ""; user = ""
            case "c": command = value
            case "L": user = value
            case "P": proto = value == "UDP" ? .udp : .tcp
            case "n":
                guard pid > 0, let parsed = parseName(value) else { continue }
                groups.add(pid: pid, command: command, user: user, host: parsed.host, port: parsed.port, proto: proto)
            default:
                break
            }
        }
        return groups.result
    }

    /// Listening TCP sockets from `netstat -anv -p tcp`, whose `process:pid` column covers every user.
    /// Returns [] if the column layout isn't the expected one.
    static func parseNetstat(output: String) -> [PortProcess] {
        var groups = Grouper()
        for line in output.split(separator: "\n") {
            let cols = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            // proto recv-q send-q local foreign state rxbytes txbytes rhiwat shiwat process:pid …
            guard cols.count > 10, cols[0].hasPrefix("tcp"), cols[5] == "LISTEN",
                  let dot = cols[3].lastIndex(of: "."), let port = Int(cols[3][cols[3].index(after: dot)...]),
                  // The process name may contain spaces: "MSP Anywhere Dae:602".
                  let end = cols[10...].firstIndex(where: { $0.contains(":") && Int($0.split(separator: ":").last ?? "") != nil }),
                  let colon = cols[end].lastIndex(of: ":"), let pid = pid_t(cols[end][cols[end].index(after: colon)...]), pid > 0
            else { continue }
            let command = (cols[10..<end] + [String(cols[end][..<colon])]).joined(separator: " ")
            groups.add(pid: pid, command: command, user: ProcInfo.owner(of: pid) ?? "", host: String(cols[3][..<dot]), port: port, proto: .tcp)
        }
        return groups.result
    }

    private static func rank(_ kind: PortProcess.Kind) -> Int {
        switch kind {
        case .dev: return 0
        case .app: return 1
        case .system: return 2
        }
    }

    /// "*:3000", "127.0.0.1:5173", "[::1]:8080" → host + port.
    /// Skips connected sockets ("a->b") and wildcard-port UDP ("*:*").
    static func parseName(_ name: String) -> (host: String, port: Int)? {
        guard !name.contains("->"), let colon = name.lastIndex(of: ":") else { return nil }
        let host = String(name[..<colon])
        guard let port = Int(name[name.index(after: colon)...]) else { return nil }
        return (host, port)
    }
}

/// Collects sockets per process, keeping first-seen order.
private struct Grouper {
    private var byPid: [pid_t: PortProcess] = [:]
    private var order: [pid_t] = []

    mutating func add(pid: pid_t, command: String, user: String, host: String, port: Int, proto: ListeningPort.Proto) {
        if byPid[pid] == nil {
            byPid[pid] = PortProcess(pid: pid, command: command, user: user)
            order.append(pid)
        }
        let loopback = ["127.0.0.1", "[::1]", "::1", "localhost"].contains(host)
        if let i = byPid[pid]!.ports.firstIndex(where: { $0.port == port && $0.proto == proto }) {
            // IPv4 + IPv6 entries for the same port: loopback only if both are.
            byPid[pid]!.ports[i].loopbackOnly = byPid[pid]!.ports[i].loopbackOnly && loopback
        } else {
            byPid[pid]!.ports.append(ListeningPort(port: port, proto: proto, loopbackOnly: loopback))
        }
    }

    var result: [PortProcess] {
        order.compactMap { byPid[$0] }.map { p in
            var p = p
            p.ports.sort { $0.port < $1.port }
            return p
        }
    }
}

enum Shell {
    static func run(_ path: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        // lsof exits with 1 when nothing matches: that's an empty list, not an error.
        return String(data: data, encoding: .utf8)
    }
}

enum ProcInfo {
    /// Current directory via proc_pidinfo; nil for processes of other users.
    static func workingDirectory(of pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        return withUnsafeBytes(of: info.pvi_cdir.vip_path) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    /// Executable path; unlike KERN_PROCARGS2 this also works for other users.
    static func path(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    /// Effective user id of any process.
    static func ownerUID(of pid: pid_t) -> uid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ucred.cr_uid
    }

    static func owner(of pid: pid_t) -> String? {
        ownerUID(of: pid).flatMap { getpwuid($0) }.map { String(cString: $0.pointee.pw_name) }
    }

    /// Executable path and argv via sysctl(KERN_PROCARGS2).
    /// Returns nil for processes of other users, which the kernel won't expose.
    static func arguments(of pid: pid_t) -> (path: String, args: [String])? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }

        let argc = buffer.withUnsafeBytes { Int($0.load(as: Int32.self)) }
        var index = MemoryLayout<Int32>.size

        func readCString() -> String {
            let start = index
            while index < size && buffer[index] != 0 { index += 1 }
            return String(decoding: buffer[start..<index], as: UTF8.self)
        }

        let path = readCString()
        while index < size && buffer[index] == 0 { index += 1 }

        var args: [String] = []
        while args.count < argc && index < size {
            args.append(readCString())
            index += 1
        }
        return (path, args)
    }
}
