import XCTest
@testable import PortPilotCore

final class PortScannerTests: XCTestCase {
    func testParseName() {
        XCTAssertEqual(PortScanner.parseName("*:3000")?.host, "*")
        XCTAssertEqual(PortScanner.parseName("*:3000")?.port, 3000)
        XCTAssertEqual(PortScanner.parseName("127.0.0.1:5173")?.host, "127.0.0.1")
        XCTAssertEqual(PortScanner.parseName("127.0.0.1:5173")?.port, 5173)
        XCTAssertEqual(PortScanner.parseName("[::1]:8080")?.host, "[::1]")
        XCTAssertEqual(PortScanner.parseName("[::1]:8080")?.port, 8080)
        XCTAssertNil(PortScanner.parseName("*:*"))
        XCTAssertNil(PortScanner.parseName("127.0.0.1:5173->127.0.0.1:61234"))
        XCTAssertNil(PortScanner.parseName("a->b"))
    }

    func testMergesIPv4AndIPv6EntriesOfTheSamePort() {
        let output = """
        p100
        cnode
        Lsimone
        f20
        PTCP
        n127.0.0.1:5173
        f21
        PTCP
        n[::1]:5173
        f22
        PTCP
        n127.0.0.1:3000
        f23
        PTCP
        n*:3000
        """
        let processes = PortScanner.parse(output: output)
        XCTAssertEqual(processes.count, 1)
        XCTAssertEqual(processes[0].ports.map(\.port), [3000, 5173])
        // Loopback only when every entry is loopback.
        XCTAssertEqual(processes[0].ports.map(\.loopbackOnly), [false, true])
    }

    func testTCPAndUDPOnTheSamePortStaySeparate() {
        let output = "p7\ncmDNSResponder\nL_mdnsresponder\nf1\nPUDP\nn*:5353\nf2\nPTCP\nn*:5353\nf3\nPUDP\nn*:*\n"
        let ports = PortScanner.parse(output: output)[0].ports
        XCTAssertEqual(ports.map(\.proto), [.udp, .tcp])
    }

    func testMultipleProcessesKeepLsofOrderAndOwners() {
        let output = """
        p200
        cPython
        Lsimone
        f5
        PTCP
        n*:8765
        p50
        cControlCe
        Lsimone
        f9
        PTCP
        n*:7000
        f10
        PTCP
        n*:5000
        p1
        claunchd
        Lroot
        f11
        PTCP
        n127.0.0.1:1234->127.0.0.1:5678
        """
        let processes = PortScanner.parse(output: output)
        XCTAssertEqual(processes.map(\.pid), [200, 50])
        XCTAssertEqual(processes.map(\.command), ["Python", "ControlCe"])
        XCTAssertEqual(processes[1].user, "simone")
        XCTAssertEqual(processes[1].ports.map(\.port), [5000, 7000])
    }

    func testEmptyOutput() {
        XCTAssertTrue(PortScanner.parse(output: "").isEmpty)
    }
}
