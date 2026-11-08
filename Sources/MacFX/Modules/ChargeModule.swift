import Foundation
import IOKit.ps

/// ChargeFX: sounds when the charger connects/disconnects, plus low-battery and charge-limit alerts.
@MainActor
final class ChargeModule: ObservableObject {
    @Published var enabled: Bool { didSet { Defaults.set(enabled, "charge.enabled") } }
    @Published var showHUD: Bool { didSet { Defaults.set(showHUD, "charge.hud") } }
    @Published var lowAlert: Bool { didSet { Defaults.set(lowAlert, "charge.lowAlert") } }
    @Published var lowThreshold: Int { didSet { Defaults.set(lowThreshold, "charge.lowThreshold") } }
    @Published var fullAlert: Bool { didSet { Defaults.set(fullAlert, "charge.fullAlert") } }
    @Published var fullThreshold: Int { didSet { Defaults.set(fullThreshold, "charge.fullThreshold") } }

    @Published private(set) var hasBattery = false
    @Published private(set) var onAC = true
    @Published private(set) var percent: Int?
    @Published private(set) var isCharging = false

    private var source: CFRunLoopSource?

    init() {
        enabled = Defaults.bool("charge.enabled", default: true)
        showHUD = Defaults.bool("charge.hud", default: true)
        lowAlert = Defaults.bool("charge.lowAlert", default: true)
        lowThreshold = Defaults.int("charge.lowThreshold", default: 20)
        fullAlert = Defaults.bool("charge.fullAlert", default: false)
        fullThreshold = Defaults.int("charge.fullThreshold", default: 80)

        refresh(announce: false)

        let context = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let module = Unmanaged<ChargeModule>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { module.refresh(announce: true) }
        }, context)?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
    }

    private func refresh(announce: Bool) {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        let nowAC = providing == kIOPMACPowerKey

        var nowPercent: Int?
        var charging = false
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let cur = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            nowPercent = cur * 100 / max
            charging = desc[kIOPSIsChargingKey] as? Bool ?? false
        }

        let oldAC = onAC
        let oldPercent = percent
        hasBattery = nowPercent != nil
        onAC = nowAC
        percent = nowPercent
        isCharging = charging

        guard announce, enabled, hasBattery else { return }
        let pctText = nowPercent.map { "\($0)%" }

        if nowAC != oldAC {
            SoundPlayer.shared.play(nowAC ? .plugIn : .unplug)
            if showHUD {
                HUD.shared.show(symbol: nowAC ? "bolt.fill" : "powerplug.portrait",
                                title: nowAC ? "Charging" : "On Battery", subtitle: pctText)
            }
            return
        }

        guard let p = nowPercent, let old = oldPercent, p != old else { return }
        if lowAlert, !nowAC, p <= lowThreshold, old > lowThreshold {
            SoundPlayer.shared.play(.unplug)
            HUD.shared.show(symbol: "battery.25percent", title: "Battery Low",
                            subtitle: "\(p)% remaining. Plug in soon.", duration: 4)
        }
        if fullAlert, nowAC, p >= fullThreshold, old < fullThreshold {
            SoundPlayer.shared.play(.plugIn)
            HUD.shared.show(symbol: "battery.100percent.bolt", title: "Charged to \(p)%",
                            subtitle: "You can unplug now.", duration: 4)
        }
    }
}
