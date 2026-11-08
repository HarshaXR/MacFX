import AVFoundation
import Foundation

/// Every sound MacFX can play. Each has a synthesized built-in version and can be replaced with a custom file.
enum SoundSlot: String, CaseIterable, Identifiable {
    case lock, unlock, plugIn, unplug, capsOn, capsOff, breakDue, deviceIn, deviceOut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lock: "Lock"
        case .unlock: "Unlock"
        case .plugIn: "Charger connected"
        case .unplug: "Charger disconnected"
        case .capsOn: "Caps Lock on"
        case .capsOff: "Caps Lock off"
        case .breakDue: "Break reminder"
        case .deviceIn: "Device connected"
        case .deviceOut: "Device disconnected"
        }
    }

    var builtIn: [Float] {
        switch self {
        case .lock:
            Synth.mix([
                (0.000, Synth.click([1850, 3700, 5200], decay: 0.006, noise: 1.2, length: 0.05, gain: 0.55)),
                (0.012, Synth.click([420, 980, 2100], decay: 0.018, noise: 0.6, length: 0.10, gain: 0.75)),
            ])
        case .unlock:
            Synth.mix([
                (0.000, Synth.click([2600, 5100], decay: 0.004, noise: 1.0, length: 0.03, gain: 0.45)),
                (0.035, Synth.click([1400, 3100, 4800], decay: 0.009, noise: 0.8, length: 0.06, gain: 0.5)),
            ])
        case .plugIn:
            Synth.mix([
                (0.00, Synth.tone(1318.5, decay: 0.12, length: 0.35, gain: 0.5)),
                (0.09, Synth.tone(1975.5, decay: 0.18, length: 0.50, gain: 0.5)),
            ])
        case .unplug:
            Synth.mix([
                (0.00, Synth.tone(1975.5, decay: 0.10, length: 0.30, gain: 0.45)),
                (0.09, Synth.tone(1318.5, decay: 0.16, length: 0.45, gain: 0.45)),
            ])
        case .capsOn:
            Synth.click([3000, 4500], decay: 0.003, noise: 0.9, length: 0.03, gain: 0.5)
        case .capsOff:
            Synth.click([1800, 2700], decay: 0.003, noise: 0.6, length: 0.03, gain: 0.4)
        case .breakDue:
            Synth.mix([
                (0.00, Synth.tone(880.0, decay: 0.25, length: 0.7, gain: 0.4)),
                (0.16, Synth.tone(1108.7, decay: 0.25, length: 0.7, gain: 0.4)),
                (0.32, Synth.tone(1318.5, decay: 0.35, length: 0.9, gain: 0.4)),
            ])
        case .deviceIn:
            Synth.mix([
                (0.00, Synth.tone(1046.5, decay: 0.06, length: 0.2, gain: 0.45)),
                (0.07, Synth.tone(1568.0, decay: 0.10, length: 0.3, gain: 0.45)),
            ])
        case .deviceOut:
            Synth.mix([
                (0.00, Synth.tone(1568.0, decay: 0.06, length: 0.2, gain: 0.4)),
                (0.07, Synth.tone(1046.5, decay: 0.10, length: 0.3, gain: 0.4)),
            ])
        }
    }
}

/// Tiny procedural synth so the app ships without any third-party audio.
enum Synth {
    static let rate = 44100.0

    /// Short percussive click: decaying sine partials plus a burst of soft noise.
    static func click(_ freqs: [Double], decay: Double, noise: Double, length: Double, gain: Double) -> [Float] {
        let n = Int(rate * length)
        var out = [Float](repeating: 0, count: n)
        var lp = 0.0
        for i in 0..<n {
            let t = Double(i) / rate
            var s = 0.0
            for (k, f) in freqs.enumerated() { s += sin(2 * .pi * f * t) / Double(k + 1) }
            lp += 0.35 * (Double.random(in: -1...1) - lp)
            s += noise * lp * exp(-t / (decay * 0.4))
            out[i] = Float(s * exp(-t / decay) * gain)
        }
        return out
    }

    /// Bell-like tone with a quick attack and exponential decay.
    static func tone(_ f: Double, decay: Double, length: Double, gain: Double) -> [Float] {
        let n = Int(rate * length)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let env = min(1, t / 0.004) * exp(-t / decay)
            let s = sin(2 * .pi * f * t) + 0.3 * sin(4 * .pi * f * t) + 0.1 * sin(6 * .pi * f * t)
            return Float(s * env * gain * 0.7)
        }
    }

    static func mix(_ parts: [(offset: Double, samples: [Float])]) -> [Float] {
        let total = parts.map { Int($0.offset * rate) + $0.samples.count }.max() ?? 0
        var out = [Float](repeating: 0, count: total)
        for p in parts {
            let o = Int(p.offset * rate)
            for (i, v) in p.samples.enumerated() { out[o + i] += v }
        }
        let peak = out.map(abs).max() ?? 1
        return peak > 0.95 ? out.map { $0 / peak * 0.95 } : out
    }

    static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes)
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(bytes)
        for s in samples { u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32767))) }
        return d
    }
}

@MainActor
final class SoundPlayer: ObservableObject {
    static let shared = SoundPlayer()

    @Published private(set) var customNames: [SoundSlot: String] = [:]
    private var players: [SoundSlot: AVAudioPlayer] = [:]
    private let defaults = UserDefaults.standard

    private init() {
        SoundSlot.allCases.forEach(load)
    }

    private func key(_ slot: SoundSlot) -> String { "sound.\(slot.rawValue)" }

    private func load(_ slot: SoundSlot) {
        var player: AVAudioPlayer?
        if let path = defaults.string(forKey: key(slot)) {
            player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            customNames[slot] = player == nil ? nil : (path as NSString).lastPathComponent
        } else {
            customNames[slot] = nil
        }
        if player == nil { player = try? AVAudioPlayer(data: Synth.wav(slot.builtIn)) }
        player?.prepareToPlay()
        players[slot] = player
    }

    func play(_ slot: SoundSlot) {
        guard let p = players[slot] else { return }
        p.volume = Float(defaults.object(forKey: "volume") as? Double ?? 0.8)
        p.currentTime = 0
        p.play()
    }

    /// Copies the chosen file into Application Support so it keeps working if the original moves.
    func setCustom(_ slot: SoundSlot, from url: URL) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacFX/Sounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("\(slot.rawValue).\(url.pathExtension)")
        try? FileManager.default.removeItem(at: dest)
        let final = (try? FileManager.default.copyItem(at: url, to: dest)) != nil ? dest : url
        defaults.set(final.path, forKey: key(slot))
        load(slot)
        play(slot)
    }

    func resetCustom(_ slot: SoundSlot) {
        defaults.removeObject(forKey: key(slot))
        load(slot)
    }
}
