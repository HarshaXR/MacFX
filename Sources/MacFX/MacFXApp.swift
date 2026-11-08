import ServiceManagement
import SwiftUI

@main
struct MacFXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    private let modules = Modules.shared

    var body: some Scene {
        Window("MacFX", id: "main") {
            ContentView()
                .modules(modules)
        }
        .defaultSize(width: 780, height: 540)

        MenuBarExtra("MacFX", systemImage: "sparkles", isInserted: $showMenuBarIcon) {
            MenuBarMenu()
                .modules(modules)
        }
    }
}

/// Owns one instance of every utility for the lifetime of the app.
@MainActor
final class Modules {
    static let shared = Modules()

    let lock: LockModule
    let charge = ChargeModule()
    let caps = CapsLockModule()
    let awake = KeepAwakeModule()
    let breaks = BreakModule()
    let music = NowPlayingModule()
    let devices = DeviceModule()

    private init() {
        Migration.importLockFXSettings()
        lock = LockModule()
    }
}

extension View {
    func modules(_ m: Modules) -> some View {
        environmentObject(m.lock)
            .environmentObject(m.charge)
            .environmentObject(m.caps)
            .environmentObject(m.awake)
            .environmentObject(m.breaks)
            .environmentObject(m.music)
            .environmentObject(m.devices)
            .environmentObject(SoundPlayer.shared)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = Modules.shared

        // First launch: start at login by default (can be turned off in General).
        if !UserDefaults.standard.bool(forKey: "didSetUpLoginItem") {
            UserDefaults.standard.set(true, forKey: "didSetUpLoginItem")
            try? SMAppService.mainApp.register()
        }

        // Hide from the Dock whenever the settings window is closed; the utilities keep running.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow, window.isMainSettingsWindow else { return }
            MainActor.assumeIsolated { NSApp.setActivationPolicy(.accessory) }
        }

        // When started at login, run quietly in the background without opening the window.
        if Self.launchedAtLogin {
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.async {
                NSApp.windows.filter(\.isMainSettingsWindow).forEach { $0.close() }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Opening MacFX again (Finder, Spotlight, Dock) while it's running brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppDelegate.showMainWindow()
        return true
    }

    static func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: \.isMainSettingsWindow)?.makeKeyAndOrderFront(nil)
    }

    private static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}

extension NSWindow {
    var isMainSettingsWindow: Bool { identifier?.rawValue.hasPrefix("main") ?? false }
}

/// Brings over settings from the standalone LockFX app, once.
enum Migration {
    static func importLockFXSettings() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedLockFX") else { return }
        d.set(true, forKey: "migratedLockFX")
        guard let old = UserDefaults(suiteName: "local.harsha.lockfx") else { return }
        if let v = old.object(forKey: "enabled") as? Bool { d.set(v, forKey: "lock.enabled") }
        if let v = old.object(forKey: "volume") as? Float { d.set(Double(v), forKey: "volume") }
        if let v = old.string(forKey: "custom.lock") { d.set(v, forKey: "sound.lock") }
        if let v = old.string(forKey: "custom.unlock") { d.set(v, forKey: "sound.unlock") }
    }
}
