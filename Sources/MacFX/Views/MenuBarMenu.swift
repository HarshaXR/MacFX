import SwiftUI

struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var lock: LockModule
    @EnvironmentObject private var charge: ChargeModule
    @EnvironmentObject private var caps: CapsLockModule
    @EnvironmentObject private var awake: KeepAwakeModule
    @EnvironmentObject private var breaks: BreakModule
    @EnvironmentObject private var music: NowPlayingModule
    @EnvironmentObject private var devices: DeviceModule

    var body: some View {
        Button("Open MacFX…") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Toggle("LockFX", isOn: $lock.enabled)
        Toggle("ChargeFX", isOn: $charge.enabled)
        Toggle("Caps Lock Alert", isOn: $caps.enabled)
        Toggle("Break Reminder", isOn: $breaks.enabled)
        Toggle("Now Playing", isOn: $music.enabled)
        Toggle("DeviceFX", isOn: $devices.enabled)
        Divider()
        if awake.isActive {
            Button("Stop Keep Awake") { awake.stop() }
        } else {
            Menu("Keep Awake") {
                ForEach(KeepAwakeModule.durations, id: \.label) { option in
                    Button(option.label) { awake.start(minutes: option.minutes) }
                }
            }
        }
        Divider()
        Button("Quit MacFX") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
