import XCTest
@testable import PortPilotCore

final class ProcessKillerTests: XCTestCase {
    func testRefusesLaunchdAndItself() async {
        let launchd = await ProcessKiller.terminate(1, force: true)
        XCTAssertEqual(launchd, .notPermitted)
        let me = await ProcessKiller.terminate(getpid(), force: true)
        XCTAssertEqual(me, .notPermitted)
    }

    func testRefusesProcessesOfOtherUsers() async throws {
        // Any root-owned process other than launchd, e.g. syslogd or configd.
        let ps = try XCTUnwrap(Shell.run("/bin/ps", ["-U", "root", "-o", "pid="]))
        let pid = try XCTUnwrap(ps.split(separator: "\n").compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }.first { $0 > 1 })
        XCTAssertEqual(ProcInfo.ownerUID(of: pid), 0)
        let outcome = await ProcessKiller.terminate(pid, force: true)
        XCTAssertEqual(outcome, .notPermitted)
    }

    func testTerminatesOwnChildWithSIGTERM() async throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        let outcome = await ProcessKiller.terminate(child.processIdentifier, force: false)
        XCTAssertEqual(outcome, .terminated)
    }
}
