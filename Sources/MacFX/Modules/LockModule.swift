import Foundation

/// LockFX: plays a sound when the Mac locks and unlocks.
@MainActor
final class LockModule: ObservableObject {
    @Published var enabled: Bool { didSet { Defaults.set(enabled, "lock.enabled") } }

    private var last: (locked: Bool, at: Date)?

    init() {
        enabled = Defaults.bool("lock.enabled", default: true)
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .screenIsLocked, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire(locked: true) }
        }
        dnc.addObserver(forName: .screenIsUnlocked, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire(locked: false) }
        }
    }

    private func fire(locked: Bool) {
        guard enabled else { return }
        // macOS sometimes posts the same notification twice in a row.
        if let last, last.locked == locked, Date().timeIntervalSince(last.at) < 1 { return }
        last = (locked, Date())
        SoundPlayer.shared.play(locked ? .lock : .unlock)
    }
}

extension Notification.Name {
    static let screenIsLocked = Notification.Name("com.apple.screenIsLocked")
    static let screenIsUnlocked = Notification.Name("com.apple.screenIsUnlocked")
}

/// Small typed helpers over UserDefaults.
enum Defaults {
    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }
    static func int(_ key: String, default value: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? value
    }
    static func set(_ value: Any?, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
