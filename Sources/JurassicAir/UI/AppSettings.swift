import Foundation
import Combine

final class AppSettings: ObservableObject {
    /// The singleton used by the running app. Tests use the `init(defaults:)`
    /// constructor with an isolated `UserDefaults(suiteName:)` so they don't
    /// pollute the real prefs.
    static let shared = AppSettings(defaults: .standard)

    /// Where pref values are persisted. Injected so tests can use a clean suite.
    private let defaults: UserDefaults

    @Published var showRenderStats: Bool {
        didSet { defaults.set(showRenderStats, forKey: "debug.showRenderStats") }
    }
    @Published var bannerAmplitude: Double {
        didSet { defaults.set(bannerAmplitude, forKey: "banner.amplitude") }
    }
    @Published var bannerFrequency: Double {
        didSet { defaults.set(bannerFrequency, forKey: "banner.frequency") }
    }
    @Published var bannerPhaseStep: Double {
        didSet { defaults.set(bannerPhaseStep, forKey: "banner.phaseStep") }
    }

    /// Single knob that scales BOTH the plane sprite and the banner uniformly.
    /// 1.0 = original size, 0.5 = half, etc. Applied at render time via SKNode.setScale,
    /// so pixel-art crispness is preserved (textures stay at their base resolution).
    @Published var displayScale: Double {
        didSet { defaults.set(displayScale, forKey: "displayScale") }
    }

    /// Horizontal flight speed in points/second. Read each frame so the slider tunes
    /// live while a plane is on-screen.
    @Published var flightSpeed: Double {
        didSet { defaults.set(flightSpeed, forKey: "flightSpeed") }
    }

    @Published var audioEnabled: Bool {
        didSet { defaults.set(audioEnabled, forKey: "audio.enabled") }
    }

    /// When false, the mid-flight character voice (sound pack) is muted but the
    /// engine drone still plays. Independent of `audioEnabled`, which is the
    /// master switch.
    @Published var characterSoundEnabled: Bool {
        didSet { defaults.set(characterSoundEnabled, forKey: "audio.characterSoundEnabled") }
    }

    // MARK: - Flier appearance (Pro features unlocked)

    /// Character head id (see `FlierCatalog.heads`).
    @Published var flierHead: String {
        didSet { defaults.set(flierHead, forKey: "flier.head") }
    }
    /// Plane base colour id (see `FlierCatalog.colors`).
    @Published var flierColor: String {
        didSet { defaults.set(flierColor, forKey: "flier.color") }
    }
    /// Banner theme id (see `ThemeCatalog.themes`).
    @Published var bannerTheme: String {
        didSet { defaults.set(bannerTheme, forKey: "banner.theme") }
    }
    /// Banner font id (see `FontCatalog.fonts`).
    @Published var bannerFont: String {
        didSet { defaults.set(bannerFont, forKey: "banner.font") }
    }
    /// Mid-flight one-shot sound pack id (see `SoundCatalog.packs`).
    @Published var soundPack: String {
        didSet { defaults.set(soundPack, forKey: "sound.pack") }
    }
    /// Flight speed preset id (multiplies `flightSpeed`).
    @Published var speedPreset: String {
        didSet { defaults.set(speedPreset, forKey: "speed.preset") }
    }

    // MARK: - Calendar

    @Published var calendarEnabled: Bool {
        didSet { defaults.set(calendarEnabled, forKey: "calendar.enabled") }
    }
    /// EKCalendar.calendarIdentifier values that should be watched.
    @Published var selectedCalendarIdentifiers: Set<String> {
        didSet {
            defaults.set(Array(selectedCalendarIdentifiers), forKey: "calendar.selectedIdentifiers")
        }
    }
    /// Minutes-before-start at which to fire a plane. e.g. `[10, 5, 0]` → three planes per event.
    @Published var alertOffsetsMinutes: [Int] {
        didSet { defaults.set(alertOffsetsMinutes, forKey: "calendar.alertOffsetsMinutes") }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let d = defaults
        self.showRenderStats = d.bool(forKey: "debug.showRenderStats")
        self.bannerAmplitude = d.object(forKey: "banner.amplitude") as? Double ?? Defaults.bannerAmplitude
        self.bannerFrequency = d.object(forKey: "banner.frequency") as? Double ?? Defaults.bannerFrequency
        self.bannerPhaseStep = d.object(forKey: "banner.phaseStep") as? Double ?? Defaults.bannerPhaseStep
        self.displayScale = d.object(forKey: "displayScale") as? Double ?? Defaults.displayScale
        self.audioEnabled = d.object(forKey: "audio.enabled") as? Bool ?? Defaults.audioEnabled
        self.characterSoundEnabled = d.object(forKey: "audio.characterSoundEnabled") as? Bool ?? Defaults.characterSoundEnabled
        self.flightSpeed = d.object(forKey: "flightSpeed") as? Double ?? Defaults.flightSpeed
        self.flierHead = d.string(forKey: "flier.head") ?? Defaults.flierHead
        self.flierColor = d.string(forKey: "flier.color") ?? Defaults.flierColor
        self.bannerTheme = d.string(forKey: "banner.theme") ?? Defaults.bannerTheme
        self.bannerFont = d.string(forKey: "banner.font") ?? Defaults.bannerFont
        self.soundPack = d.string(forKey: "sound.pack") ?? Defaults.soundPack
        self.speedPreset = d.string(forKey: "speed.preset") ?? Defaults.speedPreset
        self.calendarEnabled = d.object(forKey: "calendar.enabled") as? Bool ?? Defaults.calendarEnabled
        if let arr = d.array(forKey: "calendar.selectedIdentifiers") as? [String] {
            self.selectedCalendarIdentifiers = Set(arr)
        } else {
            self.selectedCalendarIdentifiers = []
        }
        if let arr = d.array(forKey: "calendar.alertOffsetsMinutes") as? [Int], !arr.isEmpty {
            self.alertOffsetsMinutes = arr
        } else {
            self.alertOffsetsMinutes = Defaults.alertOffsetsMinutes
        }
    }

    /// Restore visual/audio settings to their original defaults. Does NOT touch
    /// custom reminders (user data) or launch-at-login (system-managed).
    func resetToDefaults() {
        showRenderStats = false
        bannerAmplitude = Defaults.bannerAmplitude
        bannerFrequency = Defaults.bannerFrequency
        bannerPhaseStep = Defaults.bannerPhaseStep
        displayScale = Defaults.displayScale
        audioEnabled = Defaults.audioEnabled
        characterSoundEnabled = Defaults.characterSoundEnabled
        flightSpeed = Defaults.flightSpeed
        flierHead = Defaults.flierHead
        flierColor = Defaults.flierColor
        bannerTheme = Defaults.bannerTheme
        bannerFont = Defaults.bannerFont
        soundPack = Defaults.soundPack
        speedPreset = Defaults.speedPreset
        calendarEnabled = Defaults.calendarEnabled
        alertOffsetsMinutes = Defaults.alertOffsetsMinutes
        // Intentionally NOT resetting selectedCalendarIdentifiers — preserve the user's
        // calendar selection across a reset of visual prefs.
    }

    enum Defaults {
        static let bannerAmplitude: Double = 1.6
        static let bannerFrequency: Double = 3.0
        static let bannerPhaseStep: Double = 0.18
        static let displayScale: Double = 0.55
        static let audioEnabled: Bool = true
        static let characterSoundEnabled: Bool = true
        static let flightSpeed: Double = 110
        static let flierHead: String = "dino"
        static let flierColor: String = "red"
        static let bannerTheme: String = "classic"
        static let bannerFont: String = "pixel"
        static let soundPack: String = "dino"
        static let speedPreset: String = "normal"
        static let calendarEnabled: Bool = false
        static let alertOffsetsMinutes: [Int] = [10, 5, 0]
    }
}
