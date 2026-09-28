import PortPilotCore
import SwiftUI

@main
struct PortPilotApp: App {
    @StateObject private var store = PortStore()

    var body: some Scene {
        MenuBarExtra {
            PortsPanel()
                .environmentObject(store)
        } label: {
            MenuBarLabel(count: store.devProcessCount)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

struct MenuBarLabel: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "network")
            if count > 0 {
                Text(verbatim: "\(count)").monospacedDigit()
            }
        }
        .accessibilityLabel(Text("PortPilot, \(count) dev servers running"))
    }
}
