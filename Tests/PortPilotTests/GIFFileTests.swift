import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import PortPilotCore

final class GIFFileTests: XCTestCase {
    private let dir = FileManager.default.temporaryDirectory.appendingPathComponent("GIFFileTests-\(UUID())")

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func image(_ type: UTType, named name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        let ctx = try XCTUnwrap(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, try XCTUnwrap(ctx.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    func testAcceptsGIF() throws {
        XCTAssertNoThrow(try GIFFile.validate(try image(.gif, named: "ok.gif")))
    }

    func testRejectsPNGRenamedToGIF() throws {
        let png = try image(.png, named: "fake.gif")
        XCTAssertThrowsError(try GIFFile.validate(png)) { XCTAssertEqual($0 as? GIFFile.Failure, .notAGIF) }
    }

    func testRejectsText() throws {
        let url = dir.appendingPathComponent("notes.gif")
        try Data("hello".utf8).write(to: url)
        XCTAssertThrowsError(try GIFFile.validate(url)) { XCTAssertEqual($0 as? GIFFile.Failure, .notAGIF) }
    }

    func testRejectsHugeFiles() throws {
        let url = dir.appendingPathComponent("huge.gif")
        try Data(count: GIFFile.maxBytes + 1).write(to: url)
        XCTAssertThrowsError(try GIFFile.validate(url)) { XCTAssertEqual($0 as? GIFFile.Failure, .tooLarge) }
    }
}
