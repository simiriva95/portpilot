import PortPilotCore
import SwiftUI

struct PortsPanel: View {
    @EnvironmentObject private var store: PortStore
    @AppStorage(Prefs.showSystem) private var showSystem = true
    @AppStorage(Prefs.theme) private var themeID = Theme.system.id
    @AppStorage(Prefs.customAccent) private var customAccent = ""
    @AppStorage(Prefs.mascot) private var mascotID = Mascot.cat.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var confirmingKillAll = false
    @State private var listHeight: CGFloat = 0
    @State private var selection: pid_t?
    @State private var cheering = false
    @State private var cheerTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private var theme: Theme { Theme.current(id: themeID, customAccent: customAccent) }
    private var mascot: Mascot { Mascot(rawValue: mascotID) ?? .cat }
    private var selectedProcess: PortProcess? { filtered.first { $0.pid == selection } }

    enum Filter: CaseIterable, Identifiable {
        case all, dev, other
        var id: Self { self }
        var title: LocalizedStringKey {
            switch self {
            case .all: return "All"
            case .dev: return "Development"
            case .other: return "System"
            }
        }
    }

    private var filtered: [PortProcess] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return store.processes.filter { p in
            switch filter {
            case .all: if !showSystem && p.kind != .dev { return false }
            case .dev: if p.kind != .dev { return false }
            case .other: if p.kind == .dev { return false }
            }
            guard !q.isEmpty else { return true }
            return p.displayName.lowercased().contains(q)
                || p.executableName.lowercased().contains(q)
                || (p.projectHint?.lowercased().contains(q) ?? false)
                || p.ports.contains { String($0.port).hasPrefix(q) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
            Divider()
            list
            if selectedProcess != nil { shortcutHints }
            Divider()
            footer
        }
        .frame(width: 360)
        .background(ThemeWash(theme: theme))
        .background(keyboardShortcuts)
        .tint(theme.accent)
        .environment(\.theme, theme)
        .task { await store.refresh() }
        .onChange(of: query) { _ in selection = query.isEmpty ? nil : filtered.first?.pid }
        .onChange(of: store.celebrations) { _ in cheer() }
        .onDisappear { store.pendingQuit = nil }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            if mascot != .none {
                GIFView(url: mascot.url(cheering ? .cheer : .idle), animates: !reduceMotion)
                    .frame(width: 36, height: 36)
                    .scaleEffect(cheering && !reduceMotion ? 1.12 : 1)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.5), value: cheering)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Listening ports")
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                (Text("\(store.portCount) ports") + Text(verbatim: ", ") + Text("\(store.processes.count) processes"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isRefreshing && !reduceMotion ? 360 : 0))
                    .opacity(store.isRefreshing && reduceMotion ? 0.4 : 1)
                    .animation(store.isRefreshing && !reduceMotion ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                               value: store.isRefreshing)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r")
            .help("Refresh (⌘R)")
            .accessibilityLabel("Refresh")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search port or process", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule(style: .continuous).fill(Color(nsColor: .quaternaryLabelColor)))

            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var list: some View {
        if filtered.isEmpty {
            VStack(spacing: 6) {
                if mascot != .none {
                    GIFView(url: mascot.url(.sleep), animates: !reduceMotion)
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                }
                Text(store.processes.isEmpty ? "No ports in use" : "No matching ports")
                    .font(.system(size: 13, weight: .semibold))
                Text(store.processes.isEmpty ? "Start a dev server and it shows up here." : "Change the filter or search another port.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: mascot == .none ? 200 : 240)
            .padding(.horizontal, 24)
        } else {
            let clashing = store.clashingPorts
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(filtered) { process in
                            ProcessRow(process: process, clashing: clashing, isSelected: selection == process.pid)
                                .id(process.pid)
                        }
                    }
                    .padding(6)
                    .background(GeometryReader { geo in
                        // Preferences don't leave an NSScrollView-backed ScrollView, so read the size directly.
                        Color.clear
                            .onAppear { listHeight = geo.size.height }
                            .onChange(of: geo.size.height) { listHeight = $0 }
                    })
                }
                // Grows with its rows (and inline confirmations) up to 480 pt, then scrolls.
                .frame(height: min(max(listHeight, 80), 480))
                .onChange(of: selection) { pid in
                    guard let pid else { return }
                    if reduceMotion { proxy.scrollTo(pid) } else { withAnimation { proxy.scrollTo(pid) } }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if confirmingKillAll {
                HStack {
                    Text("Quit \(store.devProcessCount) dev servers?").font(.system(size: 12))
                    Spacer()
                    Button("Cancel") { confirmingKillAll = false }
                        .buttonStyle(.bordered)
                    Button("Quit All") {
                        confirmingKillAll = false
                        Task { await store.terminateAllDevServers() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .capsuleButtons()
                .controlSize(.small)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else {
                Button {
                    confirmingKillAll = true
                } label: {
                    MenuItemLabel(title: "Quit All Dev Servers", badge: store.devProcessCount, trailing: "⇧⌘⌫", destructive: true)
                }
                .buttonStyle(MenuItemButtonStyle())
                .disabled(store.devProcessCount == 0)
            }

            SettingsButton()

            Button {
                NSApp.terminate(nil)
            } label: {
                MenuItemLabel(title: "Quit PortPilot", trailing: "⌘Q")
            }
            .buttonStyle(MenuItemButtonStyle())
            .keyboardShortcut("q")
        }
        .padding(6)
    }

    // MARK: Keyboard

    /// "⏎ Open  ⌘⌫ Quit  ⌥⌘⌫ Force Quit" under the list while a row is selected.
    private var shortcutHints: some View {
        HStack(spacing: 12) {
            hint("⏎", "Open")
            hint("⌘⌫", "Quit")
            hint("⌥⌘⌫", "Force Quit")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .accessibilityHidden(true)  // the same actions are exposed on each row
    }

    private func hint(_ keys: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(verbatim: keys)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule(style: .continuous).fill(Color(nsColor: .quaternaryLabelColor)))
            Text(title)
        }
    }

    /// Invisible buttons that own the panel's key equivalents; they fire even while the search field has focus.
    private var keyboardShortcuts: some View {
        Group {
            Button("Search") { searchFocused = true }.keyboardShortcut("f")
            Button("Previous") { moveSelection(by: -1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("Next") { moveSelection(by: 1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("Open") { returnKey() }.keyboardShortcut(.return, modifiers: [])
            Button("Close") { escape() }.keyboardShortcut(.escape, modifiers: [])
            // Disabled without a selection so ⌘⌫ still deletes text in the search field.
            Button("Quit") { selectedProcess.map { store.requestQuit($0) } }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(selectedProcess == nil)
            Button("Force Quit") { selectedProcess.map { store.requestQuit($0, force: true) } }
                .keyboardShortcut(.delete, modifiers: [.command, .option])
                .disabled(selectedProcess == nil)
            Button("Quit All Dev Servers") { confirmingKillAll = true }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(store.devProcessCount == 0)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func moveSelection(by step: Int) {
        let pids = filtered.map(\.pid)
        guard !pids.isEmpty else { return }
        let current = selection.flatMap { pids.firstIndex(of: $0) } ?? (step > 0 ? -1 : pids.count)
        selection = pids[min(max(current + step, 0), pids.count - 1)]
    }

    /// Esc backs out one level: pending confirmation, then search, then the panel. dismiss() keeps
    /// MenuBarExtra's open state in sync; closing the NSWindow directly swallows the next status item click.
    private func escape() {
        if store.pendingQuit != nil {
            store.pendingQuit = nil
        } else if confirmingKillAll {
            confirmingKillAll = false
        } else if !query.isEmpty {
            query = ""
        } else {
            dismiss()
        }
    }

    /// Return confirms a pending quit, otherwise opens the selected row's first HTTP port.
    private func returnKey() {
        if store.pendingQuit != nil {
            store.confirmPendingQuit()
        } else if confirmingKillAll {
            confirmingKillAll = false
            Task { await store.terminateAllDevServers() }
        } else if let url = selectedProcess?.ports.first(where: \.isLikelyHTTP)?.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func cheer() {
        cheerTask?.cancel()
        cheering = true
        cheerTask = Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if !Task.isCancelled { cheering = false }
        }
    }
}

/// Opens the Settings scene on macOS 13 and 14+.
struct SettingsButton: View {
    var body: some View {
        if #available(macOS 14, *) {
            SettingsLink {
                MenuItemLabel(title: "Settings…", trailing: "⌘,")
            }
            .buttonStyle(MenuItemButtonStyle())
            .keyboardShortcut(",")
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
        } else {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                MenuItemLabel(title: "Settings…", trailing: "⌘,")
            }
            .buttonStyle(MenuItemButtonStyle())
            .keyboardShortcut(",")
        }
    }
}
