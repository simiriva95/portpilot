import PortPilotCore
import SwiftUI

struct PortsPanel: View {
    @EnvironmentObject private var store: PortStore
    @AppStorage(Prefs.showSystem) private var showSystem = true
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var confirmingKillAll = false

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", dev = "Development", other = "System"
        var id: Self { self }
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
            Divider()
            footer
        }
        .frame(width: 360)
        .task { await store.refresh() }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Listening ports")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(store.portCount) ports, \(store.processes.count) processes")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(store.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
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
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search port or process", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule(style: .continuous).fill(Color(nsColor: .quaternaryLabelColor).opacity(0.5)))

            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
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
                Text(store.processes.isEmpty ? "No ports in use" : "No matching ports")
                    .font(.system(size: 13, weight: .semibold))
                Text(store.processes.isEmpty ? "Start a dev server and it shows up here." : "Change the filter or search another port.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .padding(.horizontal, 24)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filtered) { process in
                        ProcessRow(process: process, clashing: store.clashingPorts)
                    }
                }
                .padding(6)
            }
            .frame(height: min(CGFloat(filtered.count) * 78 + 12, 480))
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if confirmingKillAll {
                HStack {
                    Text("Quit \(store.devProcessCount) dev servers?").font(.system(size: 12))
                    Spacer()
                    Button("Cancel") { confirmingKillAll = false }
                    Button("Quit All") {
                        confirmingKillAll = false
                        Task { await store.terminateAllDevServers() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .controlSize(.small)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else {
                Button {
                    confirmingKillAll = true
                } label: {
                    MenuItemLabel(title: "Quit All Dev Servers", trailing: "\(store.devProcessCount)", destructive: true)
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
