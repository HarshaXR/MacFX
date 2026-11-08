import CoreGraphics
import Foundation

/// Caps Lock alert: an on-screen badge and click when Caps Lock changes.
///
/// Polls the modifier state instead of using a global key monitor, so no
/// Accessibility or Input Monitoring permission is needed.
@MainActor
final class CapsLockModule: ObservableObject {
    @Published var enabled: Bool { didSet { Defaults.set(enabled, "caps.enabled") } }
    @Published var showHUD: Bool { didSet { Defaults.set(showHUD, "caps.hud") } }
    @Published var playSound: Bool { didSet { Defaults.set(playSound, "caps.sound") } }
    @Published private(set) var isOn: Bool

    private var timer: Timer?

    init() {
        enabled = Defaults.bool("caps.enabled", default: true)
        showHUD = Defaults.bool("caps.hud", default: true)
        playSound = Defaults.bool("caps.sound", default: true)
        isOn = Self.capsLockState()

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    static func capsLockState() -> Bool {
        CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
    }

    private func poll() {
        let now = Self.capsLockState()
        guard now != isOn else { return }
        isOn = now
        guard enabled else { return }
        announce(now)
    }

    func announce(_ on: Bool) {
        if showHUD {
            HUD.shared.show(symbol: on ? "capslock.fill" : "capslock",
                            title: on ? "Caps Lock On" : "Caps Lock Off", duration: 1.0)
        }
        if playSound { SoundPlayer.shared.play(on ? .capsOn : .capsOff) }
    }
}
