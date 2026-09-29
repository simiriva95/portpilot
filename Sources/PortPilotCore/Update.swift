import CryptoKit
import Foundation

/// A GitHub release as returned by `GET /repos/{owner}/{repo}/releases/latest`.
public struct Release: Decodable, Equatable, Sendable {
    public struct Asset: Decodable, Equatable, Sendable {
        public let name: String
        public let url: URL

        enum CodingKeys: String, CodingKey {
            case name, url = "browser_download_url"
        }
    }

    public let tag: String
    public let page: URL
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tag = "tag_name", page = "html_url", assets
    }

    /// "v0.1.2" → "0.1.2"
    public var version: String { tag.hasPrefix("v") ? String(tag.dropFirst()) : tag }

    public var zip: Asset? { assets.first { $0.name == "PortPilot-\(version).zip" } }
    public var checksums: Asset? { assets.first { $0.name == "SHA256SUMS.txt" } }
}

public enum Update {
    public static let repository = "simiriva95/portpilot"
    public static let latestURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!

    /// Numeric dotted comparison: "0.1.10" is newer than "0.1.9"; missing parts count as 0.
    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ v: String) -> [Int] { v.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 } }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Only files from this repository's release downloads over HTTPS are ever fetched.
    public static func isTrusted(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com"
            && url.path.hasPrefix("/\(repository)/releases/download/")
    }

    /// Expected hash for `fileName` from a `shasum -a 256` listing ("<hex>  <name>").
    public static func checksum(for fileName: String, in listing: String) -> String? {
        for line in listing.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            // shasum marks binary mode with "*name"
            if parts.count == 2, parts[1] == fileName || parts[1] == "*" + fileName, parts[0].count == 64 {
                return parts[0].lowercased()
            }
        }
        return nil
    }

    public static func sha256(of file: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: file, options: .mappedIfSafe))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
