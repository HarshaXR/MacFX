import Foundation
import IOKit.pwr_mgt

/// Keep Awake: holds a power assertion so the Mac (and optionally the display) doesn't idle-sleep.
@MainActor
final class KeepAwakeModule: ObservableObject {
    @Published var keepDisplayOn: Bool {
        didSet {
            Defaults.set(keepDisplayOn, "awake.display")
            if isActive { start(until: endsAt) }
        }
    }
    @Published private(set) var isActive = false
    @Published private(set) var endsAt: Date?

    static let durations: [(label: String, minutes: Int?)] = [
        ("15 minutes", 15), ("30 minutes", 30), ("1 hour", 60), ("2 hours", 120), ("4 hours", 240), ("Indefinitely", nil),
    ]

    private var assertion: IOPMAssertionID = 0
    private var timer: Timer?

    init() {
        keepDisplayOn = Defaults.bool("awake.display", default: true)
    }

    func start(minutes: Int?) {
        start(until: minutes.map { Date().addingTimeInterval(Double($0) * 60) })
    }

    private func start(until end: Date?) {
        releaseAssertion()
        let type = keepDisplayOn ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep
        let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "MacFX Keep Awake" as CFString, &assertion)
        guard result == kIOReturnSuccess else { return }
        isActive = true
        endsAt = end

        timer?.invalidate()
        if let end {
            let t = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.stop() }
            }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        releaseAssertion()
        isActive = false
        endsAt = nil
    }

    private func releaseAssertion() {
        if assertion != 0 {
            IOPMAssertionRelease(assertion)
            assertion = 0
        }
    }
}
