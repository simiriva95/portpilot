import PortPilotCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: PortStore
    @AppStorage(Prefs.showSystem) private var showSystem = true
    @AppStorage(Prefs.includeUDP) private var includeUDP = false
    @AppStorage(Prefs.confirmBeforeKill) private var confirmBeforeKill = true
    @AppStorage(Prefs.refreshInterval) private var refreshInterval = 5.0
    @AppStorage(Prefs.theme) private var themeID = Theme.system.id
    @AppStorage(Prefs.customAccent) private var customAccent = ""
    @AppStorage(Prefs.mascot) private var mascotID = Mascot.cat.rawValue
    @AppStorage(Prefs.celebrate) private var celebrate = true
    @AppStorage(Prefs.animateMenuBar) private var animateMenuBar = true
    @State private var gifError: String?
    @State private var customVersion = 0

    private var theme: Theme { Theme.current(id: themeID, customAccent: customAccent) }

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.launchAtLogin = $0 }
                ))
            }
            Section("Appearance") {
                themePicker
                Toggle("Custom accent color", isOn: Binding(
                    get: { !customAccent.isEmpty },
                    set: { customAccent = $0 ? (Theme.named(themeID).accent ?? .accentColor).rgbString : "" }
                ))
                if !customAccent.isEmpty {
                    ColorPicker("Accent color", selection: Binding(
                        get: { Color(rgbString: customAccent) ?? .accentColor },
                        set: { customAccent = $0.rgbString }
                    ), supportsOpacity: false)
                }
                mascotPicker
                Toggle("Celebrate when a server quits", isOn: $celebrate)
                Toggle("Animate the menu bar icon when servers start or stop", isOn: $animateMenuBar)
            }
            Section("List") {
                Toggle("Show system and app processes in All", isOn: $showSystem)
                Toggle("Include UDP ports", isOn: $includeUDP)
                    .onChange(of: includeUDP) { _ in Task { await store.refresh() } }
                Picker("Refresh every", selection: $refreshInterval) {
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("15 seconds").tag(15.0)
                    Text("1 minute").tag(60.0)
                }
                .onChange(of: refreshInterval) { _ in store.startPolling() }
            }
            Section("Quitting") {
                Toggle("Ask before quitting a dev server", isOn: $confirmBeforeKill)
                Text("PortPilot always asks before quitting system or app processes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .tint(theme.accent)
    }

    // MARK: Theme cards

    private var themePicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(Theme.all) { option in
                Button { themeID = option.id } label: { ThemeCard(theme: option, selected: option.id == themeID) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(option.id == themeID ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Mascot

    private var mascotPicker: some View {
        HStack(alignment: .center, spacing: 12) {
            Picker("Mascot", selection: $mascotID) {
                ForEach(Mascot.allCases) { Text($0.title).tag($0.rawValue) }
            }
            if let mascot = Mascot(rawValue: mascotID), mascot != .none {
                GIFView(url: mascot.url(.idle))
                    .frame(width: 36, height: 36)
                    .id(customVersion)
                    .accessibilityHidden(true)
            }
            if mascotID == Mascot.custom.rawValue {
                Button("Choose GIF…", action: chooseGIF)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let gifError {
                Text(gifError).font(.caption).foregroundStyle(Color(nsColor: .systemRed)).offset(y: 16)
            }
        }
    }

    private func chooseGIF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a GIF for your mascot")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try CustomGIF.install(from: url)
            gifError = nil
            customVersion += 1
        } catch {
            gifError = error.localizedDescription
        }
    }
}

/// Gradient swatch with the theme name; the system theme shows the macOS accent.
private struct ThemeCard: View {
    let theme: Theme
    let selected: Bool

    var body: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.wash.isEmpty
                      ? AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
                      : AnyShapeStyle(LinearGradient(colors: theme.wash, startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(
                    Circle()
                        .fill(theme.accent ?? .accentColor)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                        .padding(6),
                    alignment: .bottomTrailing
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(nsColor: .separatorColor)),
                                      lineWidth: selected ? 2.5 : 0.5)
                )
                .frame(height: 44)
            Text(theme.title)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
        }
        .contentShape(Rectangle())
    }
}
