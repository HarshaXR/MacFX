import SwiftUI

enum Page: String, CaseIterable, Identifiable, Hashable {
    case general, lock, charge, caps, awake, breaks, music, devices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .lock: "LockFX"
        case .charge: "ChargeFX"
        case .caps: "Caps Lock"
        case .awake: "Keep Awake"
        case .breaks: "Break Reminder"
        case .music: "Now Playing"
        case .devices: "DeviceFX"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .lock: "lock.fill"
        case .charge: "bolt.fill"
        case .caps: "capslock.fill"
        case .awake: "cup.and.heat.waves.fill"
        case .breaks: "figure.walk"
        case .music: "music.note"
        case .devices: "cable.connector"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .lock: .purple
        case .charge: .green
        case .caps: .orange
        case .awake: .brown
        case .breaks: .blue
        case .music: .pink
        case .devices: .teal
        }
    }

    var blurb: String {
        switch self {
        case .general: "Startup, menu bar and volume settings for MacFX."
        case .lock: "Plays a sound when your Mac locks and unlocks."
        case .charge: "Sounds when the charger connects, plus battery alerts."
        case .caps: "Shows a badge and clicks when Caps Lock turns on or off."
        case .awake: "Stops your Mac from going to sleep for a while."
        case .breaks: "Reminds you to rest your eyes after a stretch of work."
        case .music: "Shows the song when the track changes in Music or Spotify."
        case .devices: "Sounds and badges when USB devices and drives connect."
        }
    }

    static let utilities: [Page] = [.lock, .charge, .caps, .awake, .breaks, .music, .devices]
}

/// Holds the sidebar selection. (An ObservableObject rather than @State so the project
/// builds with just the Command Line Tools, which lack SwiftUI's macro plugin.)
final class SidebarSelection: ObservableObject {
    @Published var page: Page? = .lock
}

struct ContentView: View {
    @StateObject private var sidebar = SidebarSelection()

    var body: some View {
        NavigationSplitView {
            List(selection: $sidebar.page) {
                Section("Utilities") {
                    ForEach(Page.utilities) { page in
                        SidebarRow(page: page).tag(page)
                    }
                }
                Section {
                    SidebarRow(page: .general).tag(Page.general)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            switch sidebar.page ?? .lock {
            case .general: GeneralPage()
            case .lock: LockPage()
            case .charge: ChargePage()
            case .caps: CapsPage()
            case .awake: AwakePage()
            case .breaks: BreakPage()
            case .music: MusicPage()
            case .devices: DevicePage()
            }
        }
        .frame(minWidth: 700, minHeight: 480)
    }
}

private struct SidebarRow: View {
    let page: Page
    @EnvironmentObject private var lock: LockModule
    @EnvironmentObject private var charge: ChargeModule
    @EnvironmentObject private var caps: CapsLockModule
    @EnvironmentObject private var awake: KeepAwakeModule
    @EnvironmentObject private var breaks: BreakModule
    @EnvironmentObject private var music: NowPlayingModule
    @EnvironmentObject private var devices: DeviceModule

    private var isOn: Bool? {
        switch page {
        case .general: nil
        case .lock: lock.enabled
        case .charge: charge.enabled
        case .caps: caps.enabled
        case .awake: awake.isActive
        case .breaks: breaks.enabled
        case .music: music.enabled
        case .devices: devices.enabled
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            IconTile(symbol: page.symbol, color: page.color, size: 22)
            Text(page.title)
            Spacer()
            if let isOn {
                Circle()
                    .fill(isOn ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .help(isOn ? "On" : "Off")
            }
        }
        .padding(.vertical, 2)
    }
}
