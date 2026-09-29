import XCTest
@testable import PortPilotCore

final class UpdateTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(Update.isNewer("0.1.2", than: "0.1.1"))
        XCTAssertTrue(Update.isNewer("0.1.10", than: "0.1.9"))
        XCTAssertTrue(Update.isNewer("1.0", than: "0.9.9"))
        XCTAssertFalse(Update.isNewer("0.1.1", than: "0.1.1"))
        XCTAssertFalse(Update.isNewer("0.1", than: "0.1.0"))
        XCTAssertFalse(Update.isNewer("0.1.0", than: "0.1.1"))
    }

    func testDecodesGitHubRelease() throws {
        let json = """
        {"tag_name": "v0.1.2", "html_url": "https://github.com/simiriva95/portpilot/releases/tag/v0.1.2", "draft": false,
         "assets": [
          {"name": "PortPilot-0.1.2.dmg", "browser_download_url": "https://github.com/simiriva95/portpilot/releases/download/v0.1.2/PortPilot-0.1.2.dmg"},
          {"name": "PortPilot-0.1.2.zip", "browser_download_url": "https://github.com/simiriva95/portpilot/releases/download/v0.1.2/PortPilot-0.1.2.zip"},
          {"name": "SHA256SUMS.txt", "browser_download_url": "https://github.com/simiriva95/portpilot/releases/download/v0.1.2/SHA256SUMS.txt"}
         ]}
        """
        let release = try JSONDecoder().decode(Release.self, from: Data(json.utf8))
        XCTAssertEqual(release.version, "0.1.2")
        XCTAssertEqual(release.zip?.name, "PortPilot-0.1.2.zip")
        XCTAssertEqual(release.checksums?.name, "SHA256SUMS.txt")
        XCTAssertTrue(release.assets.allSatisfy { Update.isTrusted($0.url) })
    }

    func testOnlyTrustsThisRepositoryOverHTTPS() throws {
        let ok = try XCTUnwrap(URL(string: "https://github.com/simiriva95/portpilot/releases/download/v0.1.2/PortPilot-0.1.2.zip"))
        XCTAssertTrue(Update.isTrusted(ok))
        for bad in ["http://github.com/simiriva95/portpilot/releases/download/v1/a.zip",
                    "https://github.com/someone/portpilot/releases/download/v1/a.zip",
                    "https://evil.example/simiriva95/portpilot/releases/download/v1/a.zip",
                    "https://github.com/simiriva95/portpilot/archive/main.zip"] {
            XCTAssertFalse(Update.isTrusted(try XCTUnwrap(URL(string: bad))), bad)
        }
    }

    func testReadsChecksumListing() {
        let hash = String(repeating: "ab", count: 32)
        let listing = "\(hash)  PortPilot-0.1.2.dmg\n\(String(repeating: "cd", count: 32)) *PortPilot-0.1.2.zip\n"
        XCTAssertEqual(Update.checksum(for: "PortPilot-0.1.2.dmg", in: listing), hash)
        XCTAssertEqual(Update.checksum(for: "PortPilot-0.1.2.zip", in: listing), String(repeating: "cd", count: 32))
        XCTAssertNil(Update.checksum(for: "PortPilot-0.1.3.zip", in: listing))
        XCTAssertNil(Update.checksum(for: "x.zip", in: "tooshort  x.zip"))
    }

    func testSHA256OfFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sha-\(UUID()).txt")
        try Data("abc".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try Update.sha256(of: url), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
