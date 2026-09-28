import PortPilotCore
import SwiftUI
import AppKit

struct ProcessRow: View {
    @EnvironmentObject private var store: PortStore
    @AppStorage(Prefs.confirmBeforeKill) private var confirmBeforeKill = true
    let process: PortProcess
    let clashing: Set<ListeningPort.ID>
    var isSelected = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var confirming = false
    @State private var confirmingForce = false

    private var isBusy: Bool { store.busy.contains(process.pid) }
    private var isStubborn: Bool { store.stubborn.contains(process.pid) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ProcessIcon(process: process)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(process.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(process.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(process.fullCommandLine)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityTitle)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    Spacer(minLength: 0)
                    trailingControl
                }

                if confirming {
                    confirmBar
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }

                FlowLayout(spacing: 6) {
                    ForEach(process.ports) { port in
                        PortChip(port: port, isClashing: clashing.contains(port.id))
                    }
                }

                if let message = store.messages[process.pid] {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(nsColor: .systemOrange))
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovering || confirming || isSelected ? Color(nsColor: .quaternaryLabelColor) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 1.5)
                .opacity(isSelected ? 1 : 0)
        )
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: confirming)
        .contextMenu { contextMenu }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Quit")) { requestQuit() }
    }

    /// "Vite, frontend-admin, ports 5173 and 5174"
    private var accessibilityTitle: String {
        let list = process.ports.map { String($0.port) }.formatted(.list(type: .and))
        let ports = process.ports.count == 1 ? String(localized: "port \(list)") : String(localized: "ports \(list)")
        return [process.displayName, process.projectHint, ports].compactMap { $0 }.joined(separator: ", ")
    }

    @ViewBuilder
    private var trailingControl: some View {
        if isBusy {
            ProgressView().controlSize(.small).frame(width: 24, height: 24)
        } else if !process.isCurrentUser {
            Image(systemName: "lock")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .help("Owned by \(process.user). Needs administrator access.")
                .accessibilityLabel("Owned by \(process.user)")
        } else if isStubborn {
            Button("Force Quit") { Task { await store.terminate(process, force: true) } }
                .buttonStyle(.bordered)
                .capsuleButtons()
                .controlSize(.small)
                .tint(.red)
        } else {
            Button {
                requestQuit()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 15))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(hovering ? Color.primary : Color.secondary)
            .help("Quit \(process.displayName)")
            .accessibilityLabel("Quit \(process.displayName)")
        }
    }

    private var confirmBar: some View {
        HStack(spacing: 6) {
            Text(process.kind == .dev ? "Quit \(process.displayName)?" : "\(process.displayName) is not a dev server. Quit anyway?")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Cancel") { confirming = false }
                .buttonStyle(.bordered)
            Button(confirmingForce ? "Force Quit" : "Quit") {
                confirming = false
                Task { await store.terminate(process, force: confirmingForce) }
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .capsuleButtons()
        .controlSize(.small)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Copy PID") { Pasteboard.copy("\(process.pid)") }
        Button("Copy Command Line") { Pasteboard.copy(process.fullCommandLine) }
        if let path = process.appBundlePath ?? process.executablePath {
            Button("Show in Finder") { NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") }
        }
        if process.isCurrentUser {
            Divider()
            Button("Quit") { requestQuit() }
            Button("Force Quit") { requestQuit(force: true) }
        }
    }

    /// System and app processes always ask first; dev servers only if the setting says so.
    private func requestQuit(force: Bool = false) {
        if confirmBeforeKill || process.kind != .dev {
            confirmingForce = force
            confirming = true
        } else {
            Task { await store.terminate(process, force: force) }
        }
    }
}

struct PortChip: View {
    let port: ListeningPort
    let isClashing: Bool

    var body: some View {
        Button {
            if port.isLikelyHTTP, let url = port.url {
                NSWorkspace.shared.open(url)
            } else {
                Pasteboard.copy("\(port.port)")
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(verbatim: "\(port.port)")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                Text(port.proto == .udp ? "UDP" : port.loopbackOnly ? "localhost" : "all")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                if port.isLikelyHTTP {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 9)
            .frame(height: 26)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isClashing ? Color(nsColor: .systemOrange) : Color(nsColor: .separatorColor), lineWidth: isClashing ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(helpText)
        // String(port) so VoiceOver reads "5173", not a locale-grouped "5.173".
        .accessibilityLabel(port.isLikelyHTTP ? "Open localhost \(String(port.port)) in browser" : "Copy port \(String(port.port))")
        .accessibilityHint(isClashing ? Text("Another process is also bound to this port.") : Text(""))
        .contextMenu {
            if let url = port.url, port.isLikelyHTTP {
                Button("Open in Browser") { NSWorkspace.shared.open(url) }
                Button("Copy URL") { Pasteboard.copy(url.absoluteString) }
            }
            Button("Copy Port") { Pasteboard.copy("\(port.port)") }
        }
    }

    private var helpText: String {
        let number = String(port.port)
        var lines = [port.isLikelyHTTP ? String(localized: "Open http://localhost:\(number)") : String(localized: "Copy \(number)")]
        if isClashing { lines.append(String(localized: "Another process is also bound to \(number).")) }
        if !port.loopbackOnly && port.proto == .tcp { lines.append(String(localized: "Reachable from your network.")) }
        return lines.joined(separator: "\n")
    }
}

enum Pasteboard {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
