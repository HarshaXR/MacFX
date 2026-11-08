import SwiftUI
import UniformTypeIdentifiers

/// Colored rounded-square icon, like the ones in System Settings.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

/// Standard layout for a utility page: a header with icon, description and on/off switch, then settings.
struct UtilityPage<Content: View>: View {
    let page: Page
    var isOn: Binding<Bool>?
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    IconTile(symbol: page.symbol, color: page.color, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(page.title).font(.title2.weight(.semibold))
                        Text(page.blurb).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let isOn {
                        Toggle("Enabled", isOn: isOn)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }
                .padding(.vertical, 6)
            }
            content
                .disabled(isOn.map { !$0.wrappedValue } ?? false)
        }
        .formStyle(.grouped)
        .navigationTitle(page.title)
    }
}

/// A row for one sound: name, preview button, and a menu to choose a custom file.
struct SoundRow: View {
    let slot: SoundSlot
    @EnvironmentObject private var player: SoundPlayer

    var body: some View {
        LabeledContent(slot.title) {
            HStack(spacing: 8) {
                Text(player.customNames[slot] ?? "Built-in")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button {
                    player.play(slot)
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .help("Preview")
                Menu {
                    Button("Choose File…") { choose() }
                    Button("Use Built-in Sound") { player.resetCustom(slot) }
                        .disabled(player.customNames[slot] == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.message = "Choose a sound for “\(slot.title)”"
        if panel.runModal() == .OK, let url = panel.url {
            player.setCustom(slot, from: url)
        }
    }
}
