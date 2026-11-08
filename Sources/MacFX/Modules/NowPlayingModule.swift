import AppKit

/// Now Playing: shows a badge with the song when the track changes in Apple Music or Spotify.
///
/// Both apps broadcast track changes as distributed notifications, so this needs no permissions.
@MainActor
final class NowPlayingModule: ObservableObject {
    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
        var player: String
    }

    @Published var enabled: Bool { didSet { Defaults.set(enabled, "music.enabled") } }
    @Published var onlyInBackground: Bool { didSet { Defaults.set(onlyInBackground, "music.background") } }
    @Published private(set) var current: Track?
    @Published private(set) var isPlaying = false

    private static let sources: [(notification: String, bundleID: String, name: String)] = [
        ("com.apple.Music.playerInfo", "com.apple.Music", "Music"),
        ("com.spotify.client.PlaybackStateChanged", "com.spotify.client", "Spotify"),
    ]

    init() {
        enabled = Defaults.bool("music.enabled", default: true)
        onlyInBackground = Defaults.bool("music.background", default: true)

        for source in Self.sources {
            DistributedNotificationCenter.default().addObserver(
                forName: .init(source.notification), object: nil, queue: .main
            ) { [weak self] note in
                let info = note.userInfo ?? [:]
                let state = info["Player State"] as? String
                let track = Track(title: info["Name"] as? String ?? "",
                                  artist: info["Artist"] as? String ?? "",
                                  album: info["Album"] as? String ?? "",
                                  player: source.name)
                MainActor.assumeIsolated {
                    self?.update(track: track, playing: state == "Playing", bundleID: source.bundleID)
                }
            }
        }
    }

    private func update(track: Track, playing: Bool, bundleID: String) {
        let isNewTrack = track.title != current?.title || track.artist != current?.artist
        let wasPlaying = isPlaying
        isPlaying = playing
        if !track.title.isEmpty { current = track }

        guard enabled, playing, !track.title.isEmpty, isNewTrack || !wasPlaying else { return }
        if onlyInBackground, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID { return }
        show(track)
    }

    func show(_ track: Track) {
        let subtitle = [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " — ")
        HUD.shared.show(symbol: "music.note", title: track.title,
                        subtitle: subtitle.isEmpty ? nil : subtitle, duration: 3)
    }
}
