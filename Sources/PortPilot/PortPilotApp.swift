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
            MenuBarLabel(count: store.devProcessCount, frame: store.menuBarFrame)
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
    let frame: Int?
    @AppStorage(Prefs.mascot) private var mascot = Mascot.cat.rawValue

    var body: some View {
        HStack(spacing: 3) {
            if let frame, let image = Mascot(rawValue: mascot)?.menuBarFrames[safe: frame] {
                Image(nsImage: image)
            } else {
                Image(systemName: "network")
            }
            if count > 0 {
                Text(verbatim: "\(count)").monospacedDigit()
            }
        }
        .accessibilityLabel(Text("PortPilot, \(count) dev servers running"))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
