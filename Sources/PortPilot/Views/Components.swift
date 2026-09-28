import PortPilotCore
import SwiftUI
import AppKit

// MARK: - Process icon

struct ProcessIcon: View {
    let process: PortProcess
    @Environment(\.theme) private var theme

    var body: some View {
        if let image = IconCache.shared.icon(for: process) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Brand.tint(for: process, palette: theme.palette))
                .overlay(
                    Text(Brand.glyph(for: process))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)
        }
    }
}

/// Real app icons for GUI apps; nil for CLI servers, which get a tinted glyph tile instead.
@MainActor
final class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()

    func icon(for process: PortProcess) -> NSImage? {
        guard let bundle = process.appBundlePath else { return nil }
        if let hit = cache.object(forKey: bundle as NSString) { return hit }
        let image = NSWorkspace.shared.icon(forFile: bundle)
        cache.setObject(image, forKey: bundle as NSString)
        return image
    }
}

enum Brand {
    // System colors only, so tiles follow the user's appearance and accessibility settings.
    private static let known: [String: (String, Color)] = [
        "Vite": ("V", Color(nsColor: .systemIndigo)),
        "Next.js": ("N", Color(nsColor: .systemGray)),
        "Nuxt": ("Nu", Color(nsColor: .systemGreen)),
        "Astro": ("A", Color(nsColor: .systemPurple)),
        "Storybook": ("S", Color(nsColor: .systemPink)),
        "Angular": ("Ng", Color(nsColor: .systemRed)),
        "Django": ("Dj", Color(nsColor: .systemGreen)),
        "Rails": ("Rb", Color(nsColor: .systemRed)),
        "Laravel": ("L", Color(nsColor: .systemRed)),
        "postgres": ("Pg", Color(nsColor: .systemBlue)),
        "redis-server": ("R", Color(nsColor: .systemRed)),
        "mongod": ("M", Color(nsColor: .systemGreen)),
        "mysqld": ("My", Color(nsColor: .systemTeal)),
        "com.docker.backend": ("D", Color(nsColor: .systemBlue)),
        "dotnet": (".N", Color(nsColor: .systemPurple)),
        "node": ("JS", Color(nsColor: .systemGreen)),
        "python3": ("Py", Color(nsColor: .systemBlue)),
        "python": ("Py", Color(nsColor: .systemBlue)),
        "ruby": ("Rb", Color(nsColor: .systemRed)),
        "java": ("J", Color(nsColor: .systemOrange))
    ]

    /// Brand color when known; with a themed palette every dev server takes a theme color instead.
    static func tint(for p: PortProcess, palette themed: [Color]? = nil) -> Color {
        if p.kind != .dev { return Color(nsColor: .systemGray) }
        let hash = p.displayName.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        if let themed { return themed[hash % themed.count] }
        if let hit = known[p.displayName] ?? known[p.executableName] { return hit.1 }
        let palette: [NSColor] = [.systemBlue, .systemIndigo, .systemPurple, .systemPink, .systemOrange, .systemBrown, .systemTeal]
        return Color(nsColor: palette[hash % palette.count])
    }

    static func glyph(for p: PortProcess) -> String {
        if let hit = known[p.displayName] ?? known[p.executableName] { return hit.0 }
        return String(p.displayName.prefix(2)).capitalized
    }
}

// MARK: - Flow layout for port chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: min(width, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension View {
    /// Capsule-shaped bordered buttons on macOS 14+; macOS 13 keeps the default rounded rectangle.
    @ViewBuilder func capsuleButtons() -> some View {
        if #available(macOS 14, *) { buttonBorderShape(.capsule) } else { self }
    }
}

// MARK: - Native-looking menu rows in the footer

struct MenuItemLabel: View {
    let title: LocalizedStringKey
    var badge: Int? = nil
    var trailing: String? = nil
    var destructive = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let badge, badge > 0 {
                Text(verbatim: "\(badge)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .background(Capsule(style: .continuous).fill(.tint.opacity(0.18)))
            }
            Spacer()
            // Shortcut glyphs are visual only; VoiceOver reads the title.
            if let trailing { Text(verbatim: trailing).foregroundStyle(.secondary).accessibilityHidden(true) }
        }
        .font(.system(size: 13))
        .foregroundStyle(destructive ? Color(nsColor: .systemRed) : Color.primary)
    }
}

struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuItemBody(configuration: configuration)
    }

    private struct MenuItemBody: View {
        let configuration: ButtonStyle.Configuration
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .padding(.horizontal, 10)
                .frame(height: 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hovering && isEnabled ? Color(nsColor: configuration.isPressed ? .tertiaryLabelColor : .quaternaryLabelColor) : .clear)
                )
                .opacity(isEnabled ? 1 : 0.4)
                .onHover { hovering = $0 }
        }
    }
}
