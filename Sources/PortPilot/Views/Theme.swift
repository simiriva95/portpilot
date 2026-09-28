import PortPilotCore
import SwiftUI

/// A color preset for the panel. `system` stays fully native (system accent, semantic colors, no wash).
struct Theme: Identifiable, Sendable {
    let id: String
    /// English name, also the localization key.
    let name: String
    /// nil keeps the user's system accent color.
    var accent: Color?
    /// Gradient washed over the panel material; empty for none.
    let wash: [Color]
    /// Tile colors for dev servers without a brand color; nil uses the system palette.
    let palette: [Color]?

    var title: LocalizedStringKey { LocalizedStringKey(name) }
    var isNative: Bool { accent == nil && wash.isEmpty }

    static let system = Theme(id: "system", name: "System", accent: nil, wash: [], palette: nil)

    // ponytail: fixed brand colors are the point of a theme; text stays semantic so contrast holds in light and dark.
    static let all: [Theme] = [
        .system,
        Theme(id: "synthwave", name: "Synthwave", accent: Color(hex: 0xFF3EA5),
              wash: [Color(hex: 0x7B2FF7), Color(hex: 0xF107A3)],
              palette: [Color(hex: 0xFF3EA5), Color(hex: 0x00C2FF), Color(hex: 0x9D4EDD), Color(hex: 0xFFB000)]),
        Theme(id: "terminal", name: "Terminal", accent: Color(hex: 0x2FD158),
              wash: [Color(hex: 0x0B3D1E), Color(hex: 0x1F7A3A)],
              palette: [Color(hex: 0x2FD158), Color(hex: 0x16A34A), Color(hex: 0xE3B341), Color(hex: 0x4ADE80)]),
        Theme(id: "pastel", name: "Pastel", accent: Color(hex: 0xA77BFF),
              wash: [Color(hex: 0xFFB3C7), Color(hex: 0xA7D8FF)],
              palette: [Color(hex: 0xF59AB5), Color(hex: 0x8EC5FF), Color(hex: 0xB79CFF), Color(hex: 0x7ED9B5)]),
        Theme(id: "sunset", name: "Sunset", accent: Color(hex: 0xFF6B3D),
              wash: [Color(hex: 0xFF9A44), Color(hex: 0xFC6076)],
              palette: [Color(hex: 0xFF6B3D), Color(hex: 0xFC6076), Color(hex: 0xFFB347), Color(hex: 0xC0527A)]),
        Theme(id: "ocean", name: "Ocean", accent: Color(hex: 0x1FA2FF),
              wash: [Color(hex: 0x12D8FA), Color(hex: 0x0052D4)],
              palette: [Color(hex: 0x1FA2FF), Color(hex: 0x12C2C2), Color(hex: 0x3F5EFB), Color(hex: 0x5CC8FF)]),
    ]

    static func named(_ id: String) -> Theme { all.first { $0.id == id } ?? .system }

    /// The theme with the user's custom accent applied, if any.
    static func current(id: String, customAccent: String) -> Theme {
        var theme = named(id)
        if let accent = Color(rgbString: customAccent) { theme.accent = accent }
        return theme
    }
}

/// Soft gradient behind the panel content. Off with Increase Contrast.
struct ThemeWash: View {
    let theme: Theme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if !theme.wash.isEmpty && contrast != .increased {
            LinearGradient(colors: theme.wash, startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(scheme == .dark ? 0.28 : 0.2)
                .ignoresSafeArea()
        }
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.system
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// "0.12 0.5 1" (sRGB components) ↔ Color, for storing the custom accent in UserDefaults.
    init?(rgbString: String) {
        let parts = rgbString.split(separator: " ").compactMap { Double($0) }
        guard parts.count == 3 else { return nil }
        self.init(.sRGB, red: parts[0], green: parts[1], blue: parts[2])
    }

    var rgbString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "" }
        return [c.redComponent, c.greenComponent, c.blueComponent].map { String(format: "%.3f", $0) }.joined(separator: " ")
    }
}
