import ServiceManagement
import SwiftUI

/// Mirrors the login-item status so the toggle can't drift from what macOS actually has.
final class LoginItem: ObservableObject {
    @Published var isEnabled = SMAppService.mainApp.status == .enabled {
        didSet {
            guard isEnabled != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if isEnabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
}

struct GeneralPage: View {
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("volume") private var volume = 0.8
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        UtilityPage(page: .general) {
            Section("Startup") {
                Toggle("Open MacFX at login", isOn: $loginItem.isEnabled)
                Toggle("Show icon in menu bar", isOn: $showMenuBarIcon)
            }
            Section {
                LabeledContent("Volume") {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $volume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 260)
                }
            } header: {
                Text("Sound")
            } footer: {
                Text("Applies to every MacFX sound.").foregroundStyle(.secondary)
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")
                Text("Closing this window keeps MacFX running in the background. Open MacFX again from Applications or Spotlight to get back here.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LockPage: View {
    @EnvironmentObject private var lock: LockModule

    var body: some View {
        UtilityPage(page: .lock, isOn: $lock.enabled) {
            Section {
                SoundRow(slot: .lock)
                SoundRow(slot: .unlock)
            } header: {
                Text("Sounds")
            } footer: {
                Text("Press ⌃⌘Q to lock your Mac and try it.").foregroundStyle(.secondary)
            }
        }
    }
}

struct ChargePage: View {
    @EnvironmentObject private var charge: ChargeModule

    var body: some View {
        UtilityPage(page: .charge, isOn: $charge.enabled) {
            Section("Status") {
                if charge.hasBattery {
                    LabeledContent("Battery", value: charge.percent.map { "\($0)%" } ?? "—")
                    LabeledContent("Power source", value: charge.onAC ? (charge.isCharging ? "Charger (charging)" : "Charger") : "Battery")
                } else {
                    Text("This Mac doesn't have a battery, so ChargeFX has nothing to watch.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Sounds") {
                SoundRow(slot: .plugIn)
                SoundRow(slot: .unplug)
                Toggle("Show on-screen badge", isOn: $charge.showHUD)
            }
            Section("Alerts") {
                Toggle("Low battery alert", isOn: $charge.lowAlert)
                Picker("Alert when battery drops to", selection: $charge.lowThreshold) {
                    ForEach([5, 10, 15, 20, 25, 30], id: \.self) { Text("\($0)%").tag($0) }
                }
                .disabled(!charge.lowAlert)
                Toggle("Charge limit alert", isOn: $charge.fullAlert)
                Picker("Alert when charged to", selection: $charge.fullThreshold) {
                    ForEach([80, 85, 90, 95, 100], id: \.self) { Text("\($0)%").tag($0) }
                }
                .disabled(!charge.fullAlert)
            }
        }
    }
}

struct CapsPage: View {
    @EnvironmentObject private var caps: CapsLockModule

    var body: some View {
        UtilityPage(page: .caps, isOn: $caps.enabled) {
            Section("Status") {
                LabeledContent("Caps Lock", value: caps.isOn ? "On" : "Off")
            }
            Section("Alert") {
                Toggle("Show on-screen badge", isOn: $caps.showHUD)
                Toggle("Play sound", isOn: $caps.playSound)
                SoundRow(slot: .capsOn)
                SoundRow(slot: .capsOff)
                Button("Preview Badge") { caps.announce(true) }
            }
        }
    }
}

struct AwakePage: View {
    @EnvironmentObject private var awake: KeepAwakeModule

    var body: some View {
        UtilityPage(page: .awake) {
            Section("Status") {
                HStack {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(statusText(now: context.date))
                    }
                    Spacer()
                    if awake.isActive {
                        Button("Stop") { awake.stop() }
                    }
                }
            }
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(KeepAwakeModule.durations, id: \.label) { option in
                        Button {
                            awake.start(minutes: option.minutes)
                        } label: {
                            Text(option.label).frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Keep awake for")
            }
            Section {
                Toggle("Keep the display on too", isOn: $awake.keepDisplayOn)
            } footer: {
                Text("When off, the screen can still turn off but your Mac won't sleep, so downloads and other work keep going.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusText(now: Date) -> String {
        guard awake.isActive else { return "Off. Your Mac sleeps normally." }
        guard let end = awake.endsAt else { return "Awake until you turn it off" }
        let remaining = max(0, end.timeIntervalSince(now))
        let f = DateComponentsFormatter()
        f.allowedUnits = remaining >= 3600 ? [.hour, .minute] : [.minute, .second]
        f.unitsStyle = .abbreviated
        return "Awake for \(f.string(from: remaining) ?? "") more (until \(end.formatted(date: .omitted, time: .shortened)))"
    }
}

struct BreakPage: View {
    @EnvironmentObject private var breaks: BreakModule

    var body: some View {
        UtilityPage(page: .breaks, isOn: $breaks.enabled) {
            Section("Status") {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LabeledContent("Next break", value: Self.remaining(until: breaks.nextBreak, now: context.date))
                }
                HStack {
                    Button("Reset Timer") { breaks.reset() }
                    Button("Preview Reminder") { breaks.remind() }
                }
            }
            Section {
                Picker("Remind me every", selection: $breaks.intervalMinutes) {
                    ForEach(BreakModule.intervals, id: \.self) { Text("\($0) minutes").tag($0) }
                }
                SoundRow(slot: .breakDue)
            } header: {
                Text("Reminder")
            } footer: {
                Text("Locking your Mac, putting it to sleep, or stepping away for 5 minutes counts as a break and restarts the timer.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func remaining(until date: Date, now: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "in %d:%02d", s / 60, s % 60)
    }
}

struct MusicPage: View {
    @EnvironmentObject private var music: NowPlayingModule

    var body: some View {
        UtilityPage(page: .music, isOn: $music.enabled) {
            Section("Now Playing") {
                if let track = music.current {
                    LabeledContent("Song", value: track.title)
                    LabeledContent("Artist", value: track.artist)
                    LabeledContent("Player", value: "\(track.player) · \(music.isPlaying ? "Playing" : "Paused")")
                    Button("Show Badge") { music.show(track) }
                } else {
                    Text("Play something in Apple Music or Spotify and it will show up here.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Only when the music app isn't in front", isOn: $music.onlyInBackground)
            } footer: {
                Text("Works with Apple Music and Spotify. macOS doesn't let apps add widgets to the lock screen, but it shows the current song there on its own.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DevicePage: View {
    @EnvironmentObject private var devices: DeviceModule

    var body: some View {
        UtilityPage(page: .devices, isOn: $devices.enabled) {
            Section("Watch") {
                Toggle("USB devices", isOn: $devices.watchUSB)
                Toggle("External drives and disk images", isOn: $devices.watchDrives)
                Toggle("Show on-screen badge", isOn: $devices.showHUD)
            }
            Section("Sounds") {
                SoundRow(slot: .deviceIn)
                SoundRow(slot: .deviceOut)
            }
        }
    }
}
