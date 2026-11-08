import AppKit
import SwiftUI

/// A system-style on-screen badge (like the volume/brightness HUD) that floats over everything and fades out.
@MainActor
final class HUD {
    static let shared = HUD()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(symbol: String, title: String, subtitle: String? = nil, duration: TimeInterval = 1.3) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let host = NSHostingView(rootView: HUDView(symbol: symbol, title: title, subtitle: subtitle))
        panel.contentView = host
        let size = host.fittingSize
        panel.setContentSize(size)

        // Lower-center of the screen the mouse is on.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.minY + f.height * 0.16))
        }

        hideTask?.cancel()
        panel.alphaValue = panel.isVisible ? panel.alphaValue : 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }

        hideTask = Task { [weak panel] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let panel else { return }
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.35; panel.animator().alphaValue = 0 }, completionHandler: nil)
            try? await Task.sleep(for: .seconds(0.4))
            if !Task.isCancelled { panel.orderOut(nil) }
        }
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.level = .init(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return p
    }
}

private struct HUDView: View {
    let symbol: String
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 52, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(height: 64)
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(minWidth: 190, maxWidth: subtitle == nil ? 240 : 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.12)))
        .padding(20) // room for the shadow
        .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
    }
}
