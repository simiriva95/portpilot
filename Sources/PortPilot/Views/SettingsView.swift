import PortPilotCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PortStore
    @AppStorage(Prefs.showSystem) private var showSystem = true
    @AppStorage(Prefs.includeUDP) private var includeUDP = false
    @AppStorage(Prefs.confirmBeforeKill) private var confirmBeforeKill = true
    @AppStorage(Prefs.refreshInterval) private var refreshInterval = 5.0

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.launchAtLogin = $0 }
                ))
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
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
