import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Checks a user-chosen file before PortPilot copies it in as the custom mascot.
public enum GIFFile {
    public enum Failure: Error, Equatable { case notAGIF, tooLarge }

    public static let maxBytes = 10_000_000

    public static func validate(_ url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maxBytes else { throw Failure.tooLarge }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetType(source) as String? == UTType.gif.identifier,
              CGImageSourceGetCount(source) > 0 else { throw Failure.notAGIF }
    }
}
