import Foundation

public enum ProcessKiller {
    public enum Outcome: Equatable {
        case terminated
        case stillRunning
        case notPermitted
        case notFound
        case failed(Int32)
    }

    /// Sends SIGTERM (or SIGKILL when forced) and waits up to `timeout` seconds for the process to exit.
    public static func terminate(_ pid: pid_t, force: Bool, timeout: TimeInterval = 2) async -> Outcome {
        // Never PID 1, ourselves, or another user's process (even if we happen to run as root).
        guard pid > 1, pid != getpid() else { return .notPermitted }
        guard let owner = ProcInfo.ownerUID(of: pid) else { return .notFound }
        guard owner == getuid() else { return .notPermitted }

        if kill(pid, force ? SIGKILL : SIGTERM) != 0 {
            switch errno {
            case EPERM: return .notPermitted
            case ESRCH: return .notFound
            default: return .failed(errno)
            }
        }

        for _ in 0..<Int(timeout / 0.1) {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if kill(pid, 0) != 0 && errno == ESRCH { return .terminated }
        }
        return .stillRunning
    }
}
