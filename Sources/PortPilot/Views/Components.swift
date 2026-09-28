import SwiftUI
import AppKit

// MARK: - Process icon

struct ProcessIcon: View {
    let process: PortProcess

    var body: some View {
        if let image = IconCache.shared.icon(for: process) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
        } else {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Brand.tint(for: process))
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
        "Next.js": ("N", Color(nsColor: .darkGray)),
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

    static func tint(for p: PortProcess) -> Color {
        if let hit = known[p.displayName] ?? known[p.executableName] { return hit.1 }
        if p.kind != .dev { return Color(nsColor: .systemGray) }
        let palette: [Color] = [.blue, .indigo, .purple, .pink, .orange, .brown, .teal]
        let hash = p.displayName.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[hash % palette.count]
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

// MARK: - Native-looking menu rows in the footer

struct MenuItemLabel: View {
    let title: String
    var trailing: String? = nil
    var destructive = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let trailing { Text(trailing).opacity(0.6).monospacedDigit() }
        }
        .font(.system(size: 13))
        .foregroundStyle(destructive ? Color.red : Color.primary)
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
                        .fill(Color.primary.opacity(hovering && isEnabled ? (configuration.isPressed ? 0.14 : 0.08) : 0))
                )
                .opacity(isEnabled ? 1 : 0.4)
                .onHover { hovering = $0 }
        }
    }
}
