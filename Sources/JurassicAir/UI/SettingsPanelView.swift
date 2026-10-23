import SwiftUI
import AVFoundation

/// Let macOS own navigation, window chrome, form spacing, and control styling.
struct SettingsPanelView: View {
    @AppStorage("settings.page") private var selectedPage: Page = .general
    private var selection: Binding<Page?> {
        Binding(get: { selectedPage }, set: { if let page = $0 { selectedPage = page } })
    }

    enum Page: String, CaseIterable, Identifiable {
        case general = "General", appearance = "Appearance", sound = "Sound"
        case reminders = "Reminders", calendar = "Calendar", advanced = "Advanced"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .sound: return "speaker.wave.2"
            case .reminders: return "bell"
            case .calendar: return "calendar"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                SwiftUI.Section("Settings") {
                    ForEach([Page.general, .appearance, .sound]) { page in
                        Label(page.rawValue, systemImage: page.symbol).tag(page)
                    }
                }
                SwiftUI.Section("Reminders") {
                    ForEach([Page.reminders, .calendar]) { page in
                        Label(page.rawValue, systemImage: page.symbol).tag(page)
                    }
                }
                SwiftUI.Section {
                    Label(Page.advanced.rawValue, systemImage: Page.advanced.symbol)
                        .tag(Page.advanced)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Jurassic Air")
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } detail: {
            detail
                .navigationTitle(selectedPage.rawValue)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            AppDelegate.shared?.spawnPlaceholderPlane()
                        } label: {
                            Label("Preview Flight", systemImage: "paperplane")
                        }
                        .help("Send a preview flight across your screen")
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 560)
    }

    @ViewBuilder private var detail: some View {
        switch selectedPage {
        case .general: GeneralSettingsPane()
        case .appearance: AppearanceSettingsPane()
        case .sound: SoundSettingsPane()
        case .reminders: CustomRemindersListView()
        case .calendar: CalendarSettingsView()
        case .advanced: AdvancedSettingsPane()
        }
    }
}

private struct GeneralSettingsPane: View {
    @EnvironmentObject var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            SwiftUI.Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .disabled(!LaunchAtLogin.isAvailable)
                    .onChange(of: launchAtLogin) { value in
                        if !LaunchAtLogin.setEnabled(value) {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            } header: { Text("Startup") } footer: {
                Text("Keep Jurassic Air in the menu bar, ready for your next reminder.")
            }
            SwiftUI.Section {
                Picker("Speed", selection: $settings.speedPreset) {
                    ForEach(SpeedCatalog.presets) { Text($0.name).tag($0.id) }
                }
                SettingsSlider("Flight speed", value: Binding(
                    get: { settings.flightSpeed / AppSettings.Defaults.flightSpeed },
                    set: { settings.flightSpeed = $0 * AppSettings.Defaults.flightSpeed }
                ), range: (30.0 / 110)...(400.0 / 110), format: "%.2f×")
                SettingsSlider("Size", value: $settings.displayScale,
                               range: 0.2...1.5, format: "%.2f×")
            } header: { Text("Flight") } footer: {
                Text("Crossing time stays consistent across display sizes.")
            }
            SwiftUI.Section {
                LabeledContent("Try a reminder") {
                    Button("Send Reminder") { AppDelegate.shared?.triggerRandomReminder() }
                }
                LabeledContent("Try a meeting alert") {
                    Button("Send Meeting Alert") {
                        AppDelegate.shared?.dispatcher.fire(MockReminderCatalog.randomMeeting())
                    }
                }
            } header: { Text("Preview") } footer: {
                Text("Changes are saved automatically and apply to your next flight.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct SoundSettingsPane: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        Form {
            SwiftUI.Section {
                Toggle("Play flight sounds", isOn: $settings.audioEnabled)
                Toggle("Play character sounds", isOn: $settings.characterSoundEnabled)
                    .disabled(!settings.audioEnabled)
            } header: { Text("Audio") } footer: {
                Text("The engine plays during a flight. Character sounds play halfway through.")
            }
            SwiftUI.Section("Character sound") {
                Picker("Sound", selection: $settings.soundPack) {
                    ForEach(SoundCatalog.packs) { Text($0.name).tag($0.id) }
                }
                Button("Play Sample") { SoundPreview.play(id: settings.soundPack) }
            }
            .disabled(!settings.audioEnabled || !settings.characterSoundEnabled)
        }
        .formStyle(.grouped)
    }
}

private struct AppearanceSettingsPane: View {
    @EnvironmentObject var settings: AppSettings
    @AppStorage("settings.appearanceCategory") private var category: Category = .pilot
    enum Category: String, CaseIterable {
        case pilot = "Pilot", aircraft = "Aircraft", banner = "Banner"
    }

    var body: some View {
        Form {
            SwiftUI.Section {
                FlierPreview(headId: settings.flierHead, colorId: settings.flierColor,
                             themeId: settings.bannerTheme, fontId: settings.bannerFont)
                    .equatable()
                    .frame(height: 130)
            }
            SwiftUI.Section {
                Picker("Customize", selection: $category) {
                    ForEach(Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Customize appearance")
            }
            switch category {
            case .pilot:
                SwiftUI.Section("Pilot") {
                    artworkGrid {
                        ForEach(FlierCatalog.heads) { head in
                            ArtworkChoice(title: head.name, image: "thumb-head-\(head.id)",
                                          selected: settings.flierHead == head.id) {
                                settings.flierHead = head.id
                                if let sound = head.sound { settings.soundPack = sound }
                            }
                        }
                    }
                }
            case .aircraft:
                SwiftUI.Section("Aircraft") {
                    artworkGrid {
                        ForEach(FlierCatalog.colors) { plane in
                            ArtworkChoice(title: plane.name, image: "thumb-plane-\(plane.id)",
                                          selected: settings.flierColor == plane.id) {
                                settings.flierColor = plane.id
                            }
                        }
                    }
                }
            case .banner:
                SwiftUI.Section("Style") {
                    Picker("Theme", selection: $settings.bannerTheme) {
                        ForEach(ThemeCatalog.themes) { Text($0.name).tag($0.id) }
                    }
                    Picker("Font", selection: $settings.bannerFont) {
                        ForEach(FontCatalog.fonts) { Text($0.name).tag($0.id) }
                    }
                }
                SwiftUI.Section("Movement") {
                    SettingsSlider("Wave height", value: $settings.bannerAmplitude, range: 0...4, format: "%.1f")
                    SettingsSlider("Wave frequency", value: $settings.bannerFrequency, range: 0.5...10, format: "%.1f")
                    SettingsSlider("Wave spacing", value: $settings.bannerPhaseStep, range: 0...0.6, format: "%.2f")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func artworkGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 12) {
            content()
        }
        .padding(.vertical, 6)
    }
}

private struct ArtworkChoice: View {
    let title: String
    let image: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ResourceImage(name: image)
                    .frame(width: 64, height: 44)
                    .frame(maxWidth: .infinity)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28, alignment: .top)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentColor.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12),
                                  lineWidth: selected ? 2 : 0.5)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .background(.background, in: Circle())
                        .padding(5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) {
        self.title = title; self._value = value; self.range = range; self.format = format
    }
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                Slider(value: $value, in: range)
                    .frame(minWidth: 100, idealWidth: 160, maxWidth: 200)
                    .accessibilityLabel(title)
                Text(String(format: format, value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
    }
}

private struct AdvancedSettingsPane: View {
    @EnvironmentObject var settings: AppSettings
    @State private var confirmReset = false
    var body: some View {
        Form {
            SwiftUI.Section("Diagnostics") {
                Toggle("Show rendering statistics", isOn: $settings.showRenderStats)
                LabeledContent("Sprite and font resources") {
                    Button("Reload") { AppDelegate.shared?.reloadAssets() }
                }
            }
            SwiftUI.Section {
                LabeledContent("Restore default settings") {
                    Button("Reset…") { confirmReset = true }
                }
            } header: { Text("Reset") } footer: {
                Text("Your reminders, calendar selections, and login preference are kept.")
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Restore default settings?", isPresented: $confirmReset) {
            Button("Restore Defaults", role: .destructive) { settings.resetToDefaults() }
            Button("Cancel", role: .cancel) { }
        }
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
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 2 * 1024 * 1024
        cache.countLimit = 64
        return cache
    }()

    static func image(named name: String) -> NSImage? {
        if let hit = cache.object(forKey: name as NSString) { return hit }
        guard let image = PixelArtImages.image(named: name) else { return nil }
        let img = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        cache.setObject(img, forKey: name as NSString, cost: image.bytesPerRow * image.height)
        return img
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
    private let bannerScale: CGFloat = 2
    private let planeSize: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                banner
                Rectangle()
                    .fill(Color(SpriteAssets.ropeColor))
                    .frame(width: 32, height: 2)
                    .offset(y: planeSize * (0.5 - 0.438))
                plane.padding(.leading, -planeSize * 0.123)
            }
            .frame(width: 440, height: 130)
            .scaleEffect(min(1, geometry.size.width / 440))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .clipped()
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
                .offset(
                    x: FlierCatalog.color(id: colorId).propellerOffset.x / 1088 * planeSize,
                    y: -FlierCatalog.color(id: colorId).propellerOffset.y / 1088 * planeSize
                )
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
