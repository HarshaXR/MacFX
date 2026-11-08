import AppKit
import CoreGraphics

/// Break reminder: nudges you to rest after a stretch of continuous use.
/// Locking the Mac, sleeping, or stepping away for a few minutes resets the timer.
@MainActor
final class BreakModule: ObservableObject {
    @Published var enabled: Bool {
        didSet { Defaults.set(enabled, "break.enabled"); reset() }
    }
    @Published var intervalMinutes: Int {
        didSet { Defaults.set(intervalMinutes, "break.interval"); reset() }
    }
    @Published private(set) var workStart = Date()

    static let intervals = [20, 30, 45, 60, 90]
    /// Being idle this long counts as having taken a break.
    static let awayResetSeconds: TimeInterval = 5 * 60

    var nextBreak: Date { workStart.addingTimeInterval(Double(intervalMinutes) * 60) }

    private var timer: Timer?

    init() {
        enabled = Defaults.bool("break.enabled", default: true)
        intervalMinutes = Defaults.int("break.interval", default: 30)

        DistributedNotificationCenter.default().addObserver(forName: .screenIsUnlocked, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reset() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reset() }
        }

        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func reset() { workStart = Date() }

    private func tick() {
        let anyInput = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if idle >= Self.awayResetSeconds {
            reset()
            return
        }
        guard enabled, Date() >= nextBreak else { return }
        remind()
        reset()
    }

    func remind() {
        SoundPlayer.shared.play(.breakDue)
        HUD.shared.show(symbol: "figure.walk", title: "Time for a break",
                        subtitle: "You've been going for \(intervalMinutes) minutes. Look at something far away, stretch, and grab some water.",
                        duration: 7)
    }
}
