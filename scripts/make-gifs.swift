#!/usr/bin/env swift
// Generates the bundled mascot GIFs from the ASCII sprites below (CoreGraphics + ImageIO, no dependencies).
//   swift scripts/make-gifs.swift [preview.png]
// Writes Sources/PortPilot/Resources/GIFs/<animal>-{idle,sleep,cheer,menubar}.gif
import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: Sprites (16×16). . transparent  o outline  b body  s shade  l light  e eye  w eye shine  p cheek  a accent

struct Animal {
    let name: String
    let rows: [String]
    let palette: [Character: UInt32]
    /// Color under the eyes, used for closed eyelids.
    let lid: Character
}

let animals: [Animal] = [
    Animal(name: "cat", rows: [
        "................",
        "..oo........oo..",
        "..obo......obo..",
        "..obpo....opbo..",
        "..obbboooobbbo..",
        ".obbbbbbbbbbbbo.",
        ".obbbbbbbbbbbbo.",
        ".obbwebbbbwebbo.",
        ".obbeebbbbeebbo.",
        ".obpbbbaabbbpbo.",
        "..obbbllllbbbo..",
        "...obllllllbo.o.",
        "...obllllllbobo.",
        "...obllllllbobo.",
        "...obsbbbbsbbso.",
        "....oooooooooo..",
    ], palette: ["o": 0x4A2A1A, "b": 0xF4A340, "s": 0xD8782A, "l": 0xFFE9C9, "e": 0x2B1B17,
                 "w": 0xFFFFFF, "p": 0xFF8FA3, "a": 0xE0607E], lid: "b"),
    Animal(name: "penguin", rows: [
        "................",
        "................",
        ".....oooooo.....",
        "....obbbbbbo....",
        "...obbbbbbbbo...",
        "...obbbbbbbbo...",
        "..obllllllllbo..",
        "..oblwellwelbo..",
        "..obleelleelbo..",
        "..obpllaallpbo..",
        ".obbllllllllbbo.",
        "obbbllllllllbbbo",
        "obbbllllllllbbbo",
        ".obbllllllllbbo.",
        "..obbllllllbbo..",
        "....aaa..aaa....",
    ], palette: ["o": 0x1B1F3B, "b": 0x34427A, "l": 0xF5F7FF, "e": 0x11131F,
                 "w": 0xFFFFFF, "p": 0xFF9EB5, "a": 0xFFA630], lid: "l"),
    Animal(name: "fox", rows: [
        ".o............o.",
        ".oo..........oo.",
        ".obo........obo.",
        ".obbo......obbo.",
        ".obbboooooobbbo.",
        "obbbbbbbbbbbbbbo",
        "obbbbbbbbbbbbbbo",
        "obbwebbbbbbwebbo",
        "obbeebbbbbbeebbo",
        ".ollllbbbbllllo.",
        "..ollllaallllo..",
        "....ollllllo....",
        "...obbllllbbo...",
        "..obbbllllbbbo..",
        "..obbbbbbbbbbo..",
        "...oooooooooo...",
    ], palette: ["o": 0x4A1F14, "b": 0xF06A2A, "l": 0xFFF3E6, "e": 0x2A1510,
                 "w": 0xFFFFFF, "a": 0x3A1A12], lid: "b"),
    Animal(name: "frog", rows: [
        "................",
        "................",
        "..oooo....oooo..",
        ".obwebo..obwebo.",
        ".obeebboobbeebo.",
        "obbbbbbbbbbbbbbo",
        "obpbbbbbbbbbbpbo",
        "obbbboooooobbbbo",
        ".obbbbbbbbbbbbo.",
        "..obllllllllbo..",
        ".obbllllllllbbo.",
        "obbbllllllllbbbo",
        "obbbllllllllbbbo",
        ".obbbllllllbbbo.",
        ".obbbboooobbbbo.",
        "oooooo....oooooo",
    ], palette: ["o": 0x1E4020, "b": 0x5FC35A, "l": 0xD6F5B0, "e": 0x172A15,
                 "w": 0xFFFFFF, "p": 0xFF9EB5], lid: "b"),
]

// MARK: Frames

typealias Pixels = [[UInt32?]]  // nil = transparent, RGB otherwise
let canvas = 20

enum Eyes { case open, blink, closed, happy }

func sprite(_ a: Animal, eyes: Eyes) -> [[Character]] {
    a.rows.enumerated().map { y, row in
        precondition(row.count == 16, "\(a.name) row \(y) is \(row.count) wide")
        let isTop = a.rows.indices.contains(y + 1) && a.rows[y + 1].contains("e")
        return row.map { c in
            guard c == "e" || c == "w" else { return c }
            switch eyes {
            case .open: return c
            case .blink: return isTop ? a.lid : "e"
            case .closed: return isTop ? a.lid : "o"   // eyelid line at the bottom
            case .happy: return isTop ? "o" : a.lid    // ^ ^
            }
        }
    }
}

func frame(_ a: Animal, eyes: Eyes = .open, dy: Int = 0, extras: [(Int, Int, UInt32)] = []) -> Pixels {
    var px = Pixels(repeating: [UInt32?](repeating: nil, count: canvas), count: canvas)
    for (y, row) in sprite(a, eyes: eyes).enumerated() {
        for (x, c) in row.enumerated() where c != "." {
            let cy = y + 4 + dy, cx = x + 2
            if (0..<canvas).contains(cy) { px[cy][cx] = a.palette[c] ?? 0xFF00FF }
        }
    }
    for (x, y, color) in extras where (0..<canvas).contains(x) && (0..<canvas).contains(y) { px[y][x] = color }
    return px
}

func glyph(_ rows: [String], at x: Int, _ y: Int, _ color: UInt32) -> [(Int, Int, UInt32)] {
    rows.enumerated().flatMap { dy, row in row.enumerated().compactMap { dx, c in c == "#" ? (x + dx, y + dy, color) : nil } }
}

let zee = ["###", ".#.", "###"]
let smallZee = ["##", "##"]
let sparkle = [".#.", "###", ".#."]
let zColor: UInt32 = 0x8FA3D9, gold: UInt32 = 0xFFC83D, pink: UInt32 = 0xFF6FA8

func idle(_ a: Animal) -> [Pixels] {
    (0..<16).map { i in frame(a, eyes: i == 13 ? .blink : .open, dy: (i / 4) % 2) }
}

func sleep(_ a: Animal) -> [Pixels] {
    (0..<4).map { i in
        let zs = glyph(smallZee, at: 14, 3 - i % 2, zColor) + (i >= 2 ? glyph(zee, at: 16, 0, zColor) : [])
        return frame(a, eyes: .closed, dy: i / 2 == 0 ? 0 : 1, extras: zs)
    }
}

func cheer(_ a: Animal) -> [Pixels] {
    [0, -2, -4, -4, -2, 0, 0, 0].enumerated().map { i, dy in
        let sparkles = i % 2 == 0
            ? glyph(sparkle, at: 0, 2, gold) + glyph(sparkle, at: 17, 5, pink)
            : glyph(sparkle, at: 17, 1, gold) + glyph(sparkle, at: 0, 7, pink)
        return frame(a, eyes: .happy, dy: dy, extras: sparkles)
    }
}

/// Menu bar template frames: solid silhouette, eyes cut out, hopping.
func menubar(_ a: Animal) -> [Pixels] {
    let hops = [0, -1, -2, -1, 0, 0, -1, 0]
    return hops.indices.map { i -> Pixels in
        let rows = sprite(a, eyes: i == 5 ? .blink : .open)
        var px = Pixels(repeating: [UInt32?](repeating: nil, count: canvas), count: canvas)
        for (y, row) in rows.enumerated() {
            // Solid silhouette with the eyes cut out, so the template image keeps a face.
            for (x, c) in row.enumerated() where !".ew".contains(c) {
                px[y + 2 + hops[i]][x + 2] = 0x000000
            }
        }
        return px
    }
}

// MARK: Output

func image(_ px: Pixels, scale: Int) -> CGImage {
    let size = canvas * scale
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .none
    for (y, row) in px.enumerated() {
        for (x, color) in row.enumerated() {
            guard let color else { continue }
            ctx.setFillColor(red: CGFloat((color >> 16) & 0xFF) / 255, green: CGFloat((color >> 8) & 0xFF) / 255,
                             blue: CGFloat(color & 0xFF) / 255, alpha: 1)
            ctx.fill(CGRect(x: x * scale, y: (canvas - 1 - y) * scale, width: scale, height: scale))
        }
    }
    return ctx.makeImage()!
}

func writeGIF(_ frames: [Pixels], delay: Double, scale: Int, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
    CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for px in frames {
        CGImageDestinationAddImage(dest, image(px, scale: scale),
                                   [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(dest), "failed to write \(url.path)")
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let out = root.appendingPathComponent("Sources/PortPilot/Resources/GIFs")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

var sheet: [[Pixels]] = []
for a in animals {
    let sets: [(String, [Pixels], Double, Int)] = [
        ("idle", idle(a), 0.15, 8), ("sleep", sleep(a), 0.45, 8), ("cheer", cheer(a), 0.08, 8), ("menubar", menubar(a), 0.12, 2),
    ]
    for (kind, frames, delay, scale) in sets {
        writeGIF(frames, delay: delay, scale: scale, to: out.appendingPathComponent("\(a.name)-\(kind).gif"))
        sheet.append(frames)
    }
}
print("✓ \(animals.count * 4) GIFs in \(out.path)")

// Optional contact sheet for eyeballing every frame: one row per animation.
if CommandLine.arguments.count > 1 {
    let cell = canvas * 4, cols = sheet.map(\.count).max()!
    let ctx = CGContext(data: nil, width: cols * cell, height: sheet.count * cell, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(gray: 0.85, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: cols * cell, height: sheet.count * cell))
    for (r, frames) in sheet.enumerated() {
        for (c, px) in frames.enumerated() {
            ctx.draw(image(px, scale: 4), in: CGRect(x: c * cell, y: (sheet.count - 1 - r) * cell, width: cell, height: cell))
        }
    }
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}
