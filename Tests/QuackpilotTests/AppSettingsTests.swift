import XCTest
@testable import Quackpilot

/// Settings persistence + reset behavior. Each test gets an isolated
/// UserDefaults suite so it can't pollute the real prefs.
final class AppSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        // Unique suite per test → fully isolated, even when XCTest runs them
        // in parallel.
        suiteName = "quackpilot.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func testFreshSettingsUseDocumentedDefaults() {
        let s = AppSettings(defaults: defaults)
        XCTAssertEqual(s.bannerAmplitude, 1.6)
        XCTAssertEqual(s.bannerFrequency, 3.0)
        XCTAssertEqual(s.bannerPhaseStep, 0.18)
        XCTAssertEqual(s.displayScale,    0.55)
        XCTAssertEqual(s.flightSpeed,     110)
        XCTAssertEqual(s.audioEnabled,    true)
        XCTAssertEqual(s.flierHead,       "duck")
        XCTAssertEqual(s.flierColor,      "red")
        XCTAssertEqual(s.bannerTheme,     "classic")
        XCTAssertEqual(s.bannerFont,      "pixel")
        XCTAssertEqual(s.soundPack,       "quack")
        XCTAssertEqual(s.speedPreset,     "normal")
        XCTAssertEqual(s.calendarEnabled, false)
        XCTAssertEqual(s.alertOffsetsMinutes, [10, 5, 0])
        XCTAssertEqual(s.selectedCalendarIdentifiers, [])
        XCTAssertFalse(s.showPhysicsBounds)
    }

    // MARK: - Persistence round-trip

    func testEveryWritablePropertyPersistsAcrossRecreate() {
        do {
            let s = AppSettings(defaults: defaults)
            s.showPhysicsBounds = true
            s.bannerAmplitude   = 2.4
            s.bannerFrequency   = 5.5
            s.bannerPhaseStep   = 0.42
            s.displayScale      = 0.95
            s.flightSpeed       = 220
            s.audioEnabled      = false
            s.flierHead         = "dino"
            s.flierColor        = "black"
            s.bannerTheme       = "midnight"
            s.bannerFont        = "serif"
            s.soundPack         = "pigeon"
            s.speedPreset       = "ultra"
            s.calendarEnabled   = true
            s.selectedCalendarIdentifiers = ["cal-1", "cal-2"]
            s.alertOffsetsMinutes = [30, 15, 1]
        }
        let s2 = AppSettings(defaults: defaults)
        XCTAssertTrue(s2.showPhysicsBounds)
        XCTAssertEqual(s2.bannerAmplitude, 2.4)
        XCTAssertEqual(s2.bannerFrequency, 5.5)
        XCTAssertEqual(s2.bannerPhaseStep, 0.42)
        XCTAssertEqual(s2.displayScale,    0.95)
        XCTAssertEqual(s2.flightSpeed,     220)
        XCTAssertFalse(s2.audioEnabled)
        XCTAssertEqual(s2.flierHead,       "dino")
        XCTAssertEqual(s2.flierColor,      "black")
        XCTAssertEqual(s2.bannerTheme,     "midnight")
        XCTAssertEqual(s2.bannerFont,      "serif")
        XCTAssertEqual(s2.soundPack,       "pigeon")
        XCTAssertEqual(s2.speedPreset,     "ultra")
        XCTAssertTrue(s2.calendarEnabled)
        XCTAssertEqual(s2.selectedCalendarIdentifiers, ["cal-1", "cal-2"])
        XCTAssertEqual(s2.alertOffsetsMinutes, [30, 15, 1])
    }

    // MARK: - resetToDefaults

    func testResetRestoresVisualAndAudioDefaults() {
        let s = AppSettings(defaults: defaults)
        s.bannerAmplitude = 9.9
        s.displayScale    = 1.4
        s.flierHead       = "capybara"
        s.bannerTheme     = "bubblegum"
        s.soundPack       = "dino"
        s.speedPreset     = "fast"
        s.flightSpeed     = 350
        s.audioEnabled    = false
        s.bannerFont      = "mono"

        s.resetToDefaults()

        XCTAssertEqual(s.bannerAmplitude, 1.6)
        XCTAssertEqual(s.displayScale,    0.55)
        XCTAssertEqual(s.flierHead,       "duck")
        XCTAssertEqual(s.bannerTheme,     "classic")
        XCTAssertEqual(s.soundPack,       "quack")
        XCTAssertEqual(s.speedPreset,     "normal")
        XCTAssertEqual(s.flightSpeed,     110)
        XCTAssertEqual(s.audioEnabled,    true)
        XCTAssertEqual(s.bannerFont,      "pixel")
    }

    func testResetPreservesSelectedCalendars() {
        let s = AppSettings(defaults: defaults)
        s.selectedCalendarIdentifiers = ["work", "personal"]
        s.resetToDefaults()
        XCTAssertEqual(s.selectedCalendarIdentifiers, ["work", "personal"],
                       "calendar selections must survive a settings reset")
    }

    func testResetResetsAlertOffsetsAndCalendarEnabled() {
        let s = AppSettings(defaults: defaults)
        s.calendarEnabled = true
        s.alertOffsetsMinutes = [1]
        s.resetToDefaults()
        XCTAssertFalse(s.calendarEnabled)
        XCTAssertEqual(s.alertOffsetsMinutes, [10, 5, 0])
    }

    // MARK: - Edge cases

    func testEmptyAlertOffsetsArrayInDefaultsFallsBackToDefault() {
        // If a previous version wrote an empty array, we should treat it as
        // "use the default", not as "fire nothing."
        defaults.set([Int](), forKey: "calendar.alertOffsetsMinutes")
        let s = AppSettings(defaults: defaults)
        XCTAssertEqual(s.alertOffsetsMinutes, [10, 5, 0])
    }

    func testUnknownFlierHeadIdSurvivesRoundTrip() {
        // The settings layer doesn't validate against the catalog — that's the
        // catalog's job (it falls back on unknown ids). We just need to make
        // sure storing a stale id doesn't crash the next launch.
        let s = AppSettings(defaults: defaults)
        s.flierHead = "alien-from-future-pack"
        let s2 = AppSettings(defaults: defaults)
        XCTAssertEqual(s2.flierHead, "alien-from-future-pack")
        // … but the catalog still hands the user back the default duck.
        XCTAssertEqual(FlierCatalog.head(id: s2.flierHead).id, "duck")
    }
}
