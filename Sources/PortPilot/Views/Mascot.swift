import AppKit
import ImageIO
import PortPilotCore
import SwiftUI

enum Mascot: String, CaseIterable, Identifiable {
    case cat, penguin, fox, frog, bunny, panda, duck, owl, axolotl, capybara, custom, none

    enum Mood: String { case idle, sleep, cheer }

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .cat: return "Cat"
        case .penguin: return "Penguin"
        case .fox: return "Fox"
        case .frog: return "Frog"
        case .bunny: return "Bunny"
        case .panda: return "Panda"
        case .duck: return "Duck"
        case .owl: return "Owl"
        case .axolotl: return "Axolotl"
        case .capybara: return "Capybara"
        case .custom: return "Custom GIF"
        case .none: return "None"
        }
    }

    /// A custom GIF plays for every mood; a missing custom file falls back to the cat.
    func url(_ mood: Mood) -> URL? {
        switch self {
        case .none: return nil
        case .custom: return CustomGIF.exists ? CustomGIF.url : Mascot.cat.url(mood)
        default: return Assets.gif("\(rawValue)-\(mood.rawValue)")
        }
    }

    /// Template frames for the menu bar; custom GIFs can't be templates, so they use the cat.
    @MainActor var menuBarFrames: [NSImage] {
        switch self {
        case .none: return []
        case .custom: return Mascot.cat.menuBarFrames
        default: return MenuBarFrames.load(rawValue)
        }
    }
}

enum Assets {
    static func gif(_ name: String) -> URL? {
        if let url = Bundle.main.url(forResource: name, withExtension: "gif", subdirectory: "GIFs") { return url }
        // `swift run` has no .app: resources sit in SwiftPM's bundle. Never touch Bundle.module inside the .app,
        // its accessor traps when the bundle is missing.
        guard Bundle.main.bundleURL.pathExtension != "app" else { return nil }
        return Bundle.module.url(forResource: name, withExtension: "gif", subdirectory: "GIFs")
    }
}

/// The user's own mascot, copied into Application Support so it survives moving or deleting the original.
enum CustomGIF {
    static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("PortPilot/mascot.gif")
    }

    static var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Throws a user-facing message when the file is not a GIF or is too large.
    static func install(from source: URL) throws {
        do {
            try GIFFile.validate(source)
        } catch GIFFile.Failure.tooLarge {
            throw Message(String(localized: "Choose a GIF smaller than 10 MB."))
        } catch {
            throw Message(String(localized: "That file is not a GIF."))
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if exists { try FileManager.default.removeItem(at: url) }
        try FileManager.default.copyItem(at: source, to: url)
    }

    struct Message: LocalizedError {
        let errorDescription: String?
        init(_ text: String) { errorDescription = text }
    }
}

@MainActor
enum MenuBarFrames {
    private static var cache: [String: [NSImage]] = [:]

    static func load(_ animal: String) -> [NSImage] {
        if let hit = cache[animal] { return hit }
        guard let url = Assets.gif("\(animal)-menubar"), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
        let frames = (0..<CGImageSourceGetCount(source)).compactMap { i -> NSImage? in
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { return nil }
            let image = NSImage(cgImage: cg, size: NSSize(width: 18, height: 18))  // 36 px frames at 2x
            image.isTemplate = true
            return image
        }
        cache[animal] = frames
        return frames
    }
}

/// Plays a GIF with NSImageView; shows the first frame when `animates` is false (Reduce Motion).
struct GIFView: NSViewRepresentable {
    let url: URL?
    var animates = true

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.canDrawSubviewsIntoLayer = true
        // Let the SwiftUI frame decide the size, not the GIF's pixel size.
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        if context.coordinator.url != url {
            context.coordinator.url = url
            view.image = url.flatMap(NSImage.init(contentsOf:))
        }
        view.animates = animates
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var url: URL?
    }
}
