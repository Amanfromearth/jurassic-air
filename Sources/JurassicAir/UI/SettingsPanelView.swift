import SwiftUI
import AVFoundation

/// Settings panel modelled on macOS System Settings: a translucent source-list
/// sidebar on the left, a content pane on the right with a large page title,
/// optional subtitle, and stacked rounded "cards" containing form rows.
struct SettingsPanelView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var section: Section = .general

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case general, appearance, calendar, reminders, advanced
        var id: String { rawValue }

        var label: String {
            switch self {
            case .general:    return "General"
            case .appearance: return "Appearance"
            case .calendar:   return "Calendar"
            case .reminders:  return "Reminders"
            case .advanced:   return "Advanced"
            }
        }

        var symbol: String {
            switch self {
            case .general:    return "gearshape.fill"
            case .appearance: return "paintpalette.fill"
            case .calendar:   return "calendar"
            case .reminders:  return "bell.fill"
            case .advanced:   return "slider.horizontal.3"
            }
        }

        var tint: Color {
            switch self {
            case .general:    return .gray
            case .appearance: return .pink
            case .calendar:   return .red
            case .reminders:  return .orange
            case .advanced:   return .blue
            }
        }

        var pageTitle: String { label }

        var pageSubtitle: String {
            switch self {
            case .general:    return "Tune flight speed, sizing, audio, and startup."
            case .appearance: return "Pick your flier, plane colour, banner theme, and typography."
            case .calendar:   return "Get a flyover before each meeting on the calendars you choose."
            case .reminders:  return "Schedule custom reminders to fire on your terms."
            case .advanced:   return "Debug tools and global resets."
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 210)
                .background(VisualEffectBackground(material: .sidebar))
            Divider()
            content
                .background(VisualEffectBackground(material: .windowBackground))
        }
        .frame(minWidth: 820, minHeight: 580)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "airplane")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)
                Text("Jurassic Air")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 10)

            ForEach(Section.allCases) { s in
                SidebarRow(section: s, isSelected: section == s) {
                    section = s
                }
            }
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Content pane

    private var content: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                SettingsPageHeader(
                    title: section.pageTitle,
                    subtitle: section.pageSubtitle
                )

                Group {
                    switch section {
                    case .general:    GeneralSection()
                    case .appearance: AppearanceSection()
                    case .calendar:   CalendarSettingsView()
                    case .reminders:  CustomRemindersListView()
                    case .advanced:   AdvancedSection()
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .topLeading)
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    let section: SettingsPanelView.Section
    let isSelected: Bool
    let onPick: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onPick) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(section.tint.gradient)
                        .frame(width: 19, height: 19)
                    Image(systemName: section.symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(section.label)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(rowBackground)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor.opacity(0.22))
        } else if hovering {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        } else {
            Color.clear
        }
    }
}

// MARK: - Page header & cards

struct SettingsPageHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    let footer: String?
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            )
            if let footer = footer {
                Text(footer)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Single inset row with a leading label and a trailing control. Auto-adds a
/// hairline divider above unless `isFirst`.
struct FormRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let isFirst: Bool
    @ViewBuilder var trailing: () -> Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        isFirst: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isFirst = isFirst
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider().padding(.leading, 14)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

/// Full-width row containing arbitrary content (used for sliders, custom tile
/// grids, lists). Hairline divider above unless `isFirst`.
struct FormRowFullWidth<Content: View>: View {
    let isFirst: Bool
    @ViewBuilder var content: () -> Content

    init(isFirst: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.isFirst = isFirst
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isFirst {
                Divider().padding(.leading, 14)
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    var isFirst: Bool = false

    var body: some View {
        FormRowFullWidth(isFirst: isFirst) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 13))
                    Spacer()
                    Text(String(format: format, value))
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $value, in: range)
            }
        }
    }
}

/// Vibrancy background like System Settings (`.sidebar` for the source list,
/// `.windowBackground` for the content pane).
private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

// MARK: - General

private struct GeneralSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Flight") {
                FormRow("Speed preset", isFirst: true) {
                    Picker("", selection: $settings.speedPreset) {
                        ForEach(SpeedCatalog.presets) { preset in
                            Text("\(preset.name) · \(String(format: "%.1f×", preset.multiplier))")
                                .tag(preset.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }
                SliderRow(
                    title: "Base speed",
                    value: $settings.flightSpeed,
                    range: 30...400,
                    format: "%.0f px/s"
                )
                SliderRow(
                    title: "Plane + banner size",
                    value: $settings.displayScale,
                    range: 0.2...1.5,
                    format: "%.2f×"
                )
            }

            SettingsCard("Audio") {
                FormRow(
                    "Engine sound + voice",
                    subtitle: "Master switch for all flight audio.",
                    isFirst: true
                ) {
                    Toggle("", isOn: $settings.audioEnabled).labelsHidden()
                }
                FormRow(
                    "Character voice",
                    subtitle: "Mid-flight one-shot for the selected character."
                ) {
                    Toggle("", isOn: $settings.characterSoundEnabled)
                        .labelsHidden()
                        .disabled(!settings.audioEnabled)
                }
            }

            SettingsCard(
                "Startup",
                footer: LaunchAtLogin.isAvailable
                    ? nil
                    : "Run from JurassicAir.app (via ./build.sh) to enable launch at login."
            ) {
                FormRow("Launch at login", isFirst: true) {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .disabled(!LaunchAtLogin.isAvailable)
                        .onChange(of: launchAtLogin) { newValue in
                            if !LaunchAtLogin.setEnabled(newValue) {
                                launchAtLogin = LaunchAtLogin.isEnabled
                            }
                        }
                }
            }

            SettingsCard("Quick actions", footer: "Send a plane now to check your size, speed, and audio settings.") {
                FormRowFullWidth(isFirst: true) {
                    HStack(spacing: 8) {
                        Button {
                            AppDelegate.shared?.triggerRandomReminder()
                        } label: {
                            Label("Test Reminder", systemImage: "paperplane")
                        }
                        Button {
                            AppDelegate.shared?.dispatcher.fire(MockReminderCatalog.randomMeeting())
                        } label: {
                            Label("Test Meeting", systemImage: "calendar")
                        }
                        Button {
                            AppDelegate.shared?.spawnPlaceholderPlane()
                        } label: {
                            Label("Placeholder", systemImage: "airplane")
                        }
                        Spacer(minLength: 0)
                        Button {
                            AppDelegate.shared?.reloadAssets()
                        } label: {
                            Label("Reload Assets", systemImage: "arrow.clockwise")
                        }
                        .help("Reload sprite and font assets from disk")
                    }
                    .controlSize(.regular)
                }
            }
        }
    }
}

// MARK: - Appearance

private struct AppearanceSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var sub: SubTab = .flier

    enum SubTab: String, CaseIterable, Identifiable {
        case flier, banner, typo
        var id: String { rawValue }
        var label: String {
            switch self {
            case .flier:  return "Flier"
            case .banner: return "Banner"
            case .typo:   return "Typography"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Live composite preview card.
            SettingsCard {
                FormRowFullWidth(isFirst: true) {
                    FlierPreview(
                        headId: settings.flierHead,
                        colorId: settings.flierColor,
                        themeId: settings.bannerTheme,
                        fontId: settings.bannerFont
                    )
                    .equatable()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                }
            }

            Picker("", selection: $sub) {
                ForEach(SubTab.allCases) { t in Text(t.label).tag(t) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch sub {
            case .flier:  flierSub
            case .banner: bannerSub
            case .typo:   typoSub
            }
        }
    }

    private var flierSub: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Character") {
                FormRowFullWidth(isFirst: true) {
                    TileGrid(items: FlierCatalog.heads) { head in
                        TileButton(
                            selected: settings.flierHead == head.id,
                            title: head.name,
                            content: {
                                ResourceImage(name: "thumb-head-\(head.id)")
                                    .frame(width: 56, height: 56)
                            },
                            onPick: {
                                settings.flierHead = head.id
                                settings.soundPack = head.sound
                                SoundPreview.play(id: head.sound)
                            }
                        )
                    }
                }
            }
            SettingsCard("Plane colour") {
                FormRowFullWidth(isFirst: true) {
                    TileGrid(items: FlierCatalog.colors) { color in
                        TileButton(
                            selected: settings.flierColor == color.id,
                            title: color.name,
                            content: {
                                ResourceImage(name: "thumb-plane-\(color.id)")
                                    .frame(width: 56, height: 56)
                            },
                            onPick: { settings.flierColor = color.id }
                        )
                    }
                }
            }
            SettingsCard("Sound pack") {
                FormRowFullWidth(isFirst: true) {
                    TileGrid(items: SoundCatalog.packs) { pack in
                        TileButton(
                            selected: settings.soundPack == pack.id,
                            title: pack.name,
                            content: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 22))
                                    .frame(width: 56, height: 56)
                                    .foregroundStyle(.secondary)
                            },
                            onPick: {
                                settings.soundPack = pack.id
                                SoundPreview.play(id: pack.id)
                            }
                        )
                    }
                }
            }
        }
    }

    private var bannerSub: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Theme") {
                FormRowFullWidth(isFirst: true) {
                    TileGrid(items: ThemeCatalog.themes) { theme in
                        TileButton(
                            selected: settings.bannerTheme == theme.id,
                            title: theme.name,
                            content: { ThemeSwatch(theme: theme).frame(width: 88, height: 36) },
                            onPick: { settings.bannerTheme = theme.id }
                        )
                    }
                }
            }
            SettingsCard("Banner wave") {
                SliderRow(title: "Amplitude",  value: $settings.bannerAmplitude,  range: 0...4,     format: "%.2f", isFirst: true)
                SliderRow(title: "Frequency",  value: $settings.bannerFrequency,  range: 0.5...10,  format: "%.2f")
                SliderRow(title: "Phase step", value: $settings.bannerPhaseStep,  range: 0...0.6,   format: "%.2f")
            }
        }
    }

    private var typoSub: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Font") {
                FormRowFullWidth(isFirst: true) {
                    TileGrid(items: FontCatalog.fonts) { font in
                        TileButton(
                            selected: settings.bannerFont == font.id,
                            title: font.name,
                            content: {
                                Text("Hello")
                                    .font(swiftUIFont(for: font, size: 16))
                                    .frame(width: 88, height: 36)
                            },
                            onPick: { settings.bannerFont = font.id }
                        )
                    }
                }
            }
        }
    }

    /// Best-effort SwiftUI font for the live preview tile — falls back to
    /// system if the bundled pixel font hasn't been registered yet.
    private func swiftUIFont(for font: BannerFont, size: CGFloat) -> Font {
        if font.isPixel {
            SpriteAssets.registerPixelFont()
            return .custom(SpriteAssets.pixelFontName, size: size - 4)
        }
        let ns = font.resolve(size)
        return .custom(ns.fontName, size: size)
    }
}

// MARK: - Advanced

private struct AdvancedSection: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showingResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Debug") {
                FormRow(
                    "Show render stats",
                    subtitle: "Overlay FPS, node count, and draw count on the flight scene.",
                    isFirst: true
                ) {
                    Toggle("", isOn: $settings.showRenderStats).labelsHidden()
                }
            }

            SettingsCard(
                "Reset",
                footer: "Custom reminders, calendar selections, and launch-at-login are not affected."
            ) {
                FormRow(
                    "Restore default settings",
                    subtitle: "Reverts appearance, audio, flight speed, and debug flags.",
                    isFirst: true
                ) {
                    Button("Reset…", role: .destructive) { showingResetConfirm = true }
                }
            }
        }
        .confirmationDialog(
            "Reset all settings to defaults?",
            isPresented: $showingResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { settings.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Shared widgets

private struct TileGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(items) { content($0) }
        }
    }
}

private struct TileButton<Content: View>: View {
    let selected: Bool
    let title: String
    @ViewBuilder let content: () -> Content
    let onPick: () -> Void
    var body: some View {
        Button(action: onPick) {
            VStack(spacing: 8) {
                content()
                Text(title)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08),
                                  lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ResourceImage: View {
    let name: String
    var body: some View {
        if let img = ResourceImageCache.image(named: name) {
            Image(nsImage: img).resizable().interpolation(.none).scaledToFit()
        } else {
            Image(systemName: "questionmark.square.dashed").foregroundStyle(.tertiary)
        }
    }
}

/// Bundled PNGs decoded one time. Without this, every SwiftUI body pass (for
/// example each tick of a slider drag) read every tile image from disk again.
private enum ResourceImageCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(named name: String) -> NSImage? {
        if let hit = cache.object(forKey: name as NSString) { return hit }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }
}

private struct ThemeSwatch: View {
    let theme: BannerTheme
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(theme.body.nsColor)
                Canvas { ctx, size in
                    let step: CGFloat = 10
                    var x: CGFloat = -size.height
                    while x < size.width {
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + step / 2, y: 0))
                            p.addLine(to: CGPoint(x: x + step / 2 + size.height, y: size.height))
                            p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                            p.closeSubpath()
                        }
                        ctx.fill(path, with: .color(Color(theme.stripe.nsColor)))
                        x += step
                    }
                }
                Text("Aa")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(Color(theme.text.nsColor))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(theme.border.nsColor), lineWidth: 1)
            )
        }
    }
}

/// Live preview of the flier: the real pixel banner (rendered by
/// `BannerRibbon` with the current theme and font) trailing on a rope behind
/// the composited plane, on a soft sky backdrop.
///
/// Equatable so SwiftUI skips the banner render when unrelated settings
/// (for example a slider) change.
private struct FlierPreview: View, Equatable {
    let headId: String
    let colorId: String
    let themeId: String
    let fontId: String

    /// Upscale factor for the banner bitmap. Integer keeps pixels square.
    private let bannerScale: CGFloat = 3
    private let planeSize: CGFloat = 120

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.14), Color.accentColor.opacity(0.03)],
                    startPoint: .top, endPoint: .bottom
                ))

            HStack(spacing: 0) {
                banner
                Rectangle()
                    .fill(Color(SpriteAssets.ropeColor))
                    .frame(width: 44, height: 2)
                    .offset(y: planeSize * (0.5 - 0.438))
                plane
                    // The rope tucks into the fuselage at 12.3% of the plane width.
                    .padding(.leading, -planeSize * 0.123)
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the plane and banner")
    }

    @ViewBuilder
    private var banner: some View {
        // Rope and banner sit on the propeller axis, slightly below the
        // plane's centre (relY 0.438, bottom-up).
        if let image = BannerRibbon.previewImage(text: "YOUR REMINDER") {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(width: CGFloat(image.width) * bannerScale,
                       height: CGFloat(image.height) * bannerScale)
                .offset(y: planeSize * (0.5 - 0.438))
        }
    }

    private var plane: some View {
        ZStack {
            ResourceImage(name: "plane-\(colorId)-base")
            ResourceImage(name: "head-\(headId)")
            ResourceImage(name: "blade")
        }
        .frame(width: planeSize, height: planeSize)
    }
}

// MARK: - Sound preview

private enum SoundPreview {
    private static var player: AVAudioPlayer?

    static func play(id: String) {
        let pack = SoundCatalog.pack(id: id)
        guard let url = Bundle.module.url(forResource: pack.resource, withExtension: pack.ext) else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 0.85
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            NSLog("sound preview failed: \(error)")
        }
    }
}
