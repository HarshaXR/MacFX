import AppKit
import IOKit
import IOKit.usb

/// DeviceFX: sound and badge when USB devices or drives connect and disconnect.
@MainActor
final class DeviceModule: ObservableObject {
    @Published var enabled: Bool { didSet { Defaults.set(enabled, "device.enabled") } }
    @Published var watchUSB: Bool { didSet { Defaults.set(watchUSB, "device.usb") } }
    @Published var watchDrives: Bool { didSet { Defaults.set(watchDrives, "device.drives") } }
    @Published var showHUD: Bool { didSet { Defaults.set(showHUD, "device.hud") } }

    private var port: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var lastSound = Date.distantPast

    init() {
        enabled = Defaults.bool("device.enabled", default: true)
        watchUSB = Defaults.bool("device.usb", default: true)
        watchDrives = Defaults.bool("device.drives", default: true)
        showHUD = Defaults.bool("device.hud", default: true)
        startUSBWatch()
        startDriveWatch()
    }

    // MARK: USB

    private func startUSBWatch() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOUSBHostDevice"), { ctx, iterator in
            guard let ctx else { return }
            let module = Unmanaged<DeviceModule>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { module.usbChanged(iterator, connected: true) }
        }, context, &addedIterator)

        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, IOServiceMatching("IOUSBHostDevice"), { ctx, iterator in
            guard let ctx else { return }
            let module = Unmanaged<DeviceModule>.fromOpaque(ctx).takeUnretainedValue()
            MainActor.assumeIsolated { module.usbChanged(iterator, connected: false) }
        }, context, &removedIterator)

        // Drain the iterators to arm the notifications; these are devices already plugged in.
        _ = Self.deviceNames(addedIterator)
        _ = Self.deviceNames(removedIterator)
    }

    private func usbChanged(_ iterator: io_iterator_t, connected: Bool) {
        let names = Self.deviceNames(iterator)
        guard enabled, watchUSB, let name = names.first else { return }
        announce(symbol: connected ? "cable.connector" : "cable.connector.slash",
                 title: connected ? "Connected" : "Disconnected", subtitle: name, connected: connected)
    }

    private static func deviceNames(_ iterator: io_iterator_t) -> [String] {
        var names: [String] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let name = IORegistryEntryCreateCFProperty(service, "USB Product Name" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String {
                names.append(name)
            } else {
                var buf = [CChar](repeating: 0, count: 128)
                IORegistryEntryGetName(service, &buf)
                names.append(String(cString: buf))
            }
        }
        return names
    }

    // MARK: Drives

    private func startDriveWatch() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
            let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
            MainActor.assumeIsolated { self?.driveChanged(url, mounted: true) }
        }
        nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] note in
            let url = note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
            MainActor.assumeIsolated { self?.driveChanged(url, mounted: false) }
        }
    }

    private func driveChanged(_ url: URL?, mounted: Bool) {
        guard enabled, watchDrives, let url else { return }
        let values = try? url.resourceValues(forKeys: [.volumeIsInternalKey, .volumeLocalizedNameKey])
        if values?.volumeIsInternal == true { return }
        let name = values?.volumeLocalizedName ?? url.lastPathComponent
        announce(symbol: mounted ? "externaldrive.fill.badge.checkmark" : "externaldrive.badge.minus",
                 title: mounted ? "Drive Connected" : "Drive Ejected", subtitle: name, connected: mounted)
    }

    // MARK: Output

    private func announce(symbol: String, title: String, subtitle: String, connected: Bool) {
        // Plugging in a flash drive fires both a USB and a mount event; play only one sound.
        if Date().timeIntervalSince(lastSound) > 2 {
            SoundPlayer.shared.play(connected ? .deviceIn : .deviceOut)
            lastSound = Date()
        }
        if showHUD { HUD.shared.show(symbol: symbol, title: title, subtitle: subtitle, duration: 2) }
    }
}
