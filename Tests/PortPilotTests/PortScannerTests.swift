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

    func testNetstatSeesOtherUsersAndNamesWithSpaces() {
        let output = """
        Active Internet connections (including servers)
        Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)          rxbytes      txbytes  rhiwat  shiwat          process:pid    state  options           gencnt    flags   flags1 usecnt rtncnt fltrs
        tcp4       0      0  127.0.0.1.8021         *.*                    LISTEN                 0            0  131072  131072          launchd:1      00180 00000006 0000000000000ad2 00000000 00000800      1      0 000000
        tcp6       0      0  ::1.8021               *.*                    LISTEN                 0            0  131072  131072          launchd:1      00180 00000006 0000000000000ad1 00000000 00000800      1      0 000000
        tcp46      0      0  *.5948                 *.*                    LISTEN                 0            0  131072  131072 MSP Anywhere Dae:602    00180 00000006 0000000000310e22 00000000 00000800      1      0 000000
        tcp4       0      0  127.0.0.1.5173         127.0.0.1.61234        ESTABLISHED            0            0  131072  131072             node:4711   00100 00000106 00000000002bf8e4 00000001 00000800      1      0 000000
        """
        let processes = PortScanner.parseNetstat(output: output)
        XCTAssertEqual(processes.map(\.pid), [1, 602])
        XCTAssertEqual(processes[0].ports.map(\.port), [8021])
        XCTAssertEqual(processes[0].ports.map(\.loopbackOnly), [true])
        XCTAssertEqual(processes[1].command, "MSP Anywhere Dae")
        XCTAssertEqual(processes[1].ports.map(\.loopbackOnly), [false])
    }

    func testNetstatWithUnknownLayoutYieldsNothing() {
        let output = "tcp4  0  0  *.22  *.*  LISTEN  131072  131072  0  0  0x0080  0x00000006\n"
        XCTAssertTrue(PortScanner.parseNetstat(output: output).isEmpty)
    }

    func testEmptyOutput() {
        XCTAssertTrue(PortScanner.parse(output: "").isEmpty)
    }
}
