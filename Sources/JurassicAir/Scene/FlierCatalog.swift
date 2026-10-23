import AppKit

/// The flier is composed: a character HEAD sits on a coloured plane BASE, with
/// a spinning BLADE on top. All three images share a 1088×1088 canvas so they
/// overlay cleanly at the same scale.
///
/// Pulled from the QuakPit Pro catalog (https://quakpit.app) — this build of
/// Jurassic Air is local-personal-use, so everything is unlocked.

struct Head: Identifiable, Hashable {
    let id: String
    let name: String
    /// Sound pack auto-selected for animal characters; nil keeps the current pack.
    let sound: String?
}

struct PlaneColor: Identifiable, Hashable {
    let id: String
    let name: String
    /// Swatch colour used in the settings tile.
    let swatch: NSColor
    /// Propeller adjustment in source pixels, with positive Y pointing up.
    var propellerOffset: CGPoint = .zero
}

enum FlierCatalog {
    static let heads: [Head] = [
        Head(id: "dino",     name: "Dino",     sound: "dino"),
        Head(id: "duck",     name: "Duck",     sound: "quack"),
        Head(id: "corgi",    name: "Corgi",    sound: "corgi"),
        Head(id: "pigeon",   name: "Pigeon",   sound: "pigeon"),
        Head(id: "capybara", name: "Capybara", sound: "capybara"),
        Head(id: "porco",    name: "Porco Rosso", sound: nil),
        Head(id: "aviator",  name: "Soldier", sound: nil)
    ]

    static let colors: [PlaneColor] = [
        PlaneColor(id: "red",   name: "Red",   swatch: NSColor(srgbRed: 0.90, green: 0.27, blue: 0.27, alpha: 1)),
        PlaneColor(id: "blue",  name: "Blue",  swatch: NSColor(srgbRed: 0.23, green: 0.51, blue: 0.96, alpha: 1)),
        PlaneColor(id: "green", name: "Green", swatch: NSColor(srgbRed: 0.13, green: 0.74, blue: 0.42, alpha: 1)),
        PlaneColor(id: "pink",  name: "Pink",  swatch: NSColor(srgbRed: 0.96, green: 0.40, blue: 0.72, alpha: 1)),
        PlaneColor(id: "black", name: "Black", swatch: NSColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)),
        PlaneColor(id: "military", name: "WWII Fighter", swatch: NSColor(srgbRed: 0.40, green: 0.44, blue: 0.23, alpha: 1), propellerOffset: CGPoint(x: -17, y: 0)),
        PlaneColor(id: "shark", name: "Shark Fighter", swatch: NSColor(srgbRed: 0.63, green: 0.53, blue: 0.29, alpha: 1), propellerOffset: CGPoint(x: -17, y: 0)),
        PlaneColor(id: "navy", name: "Navy Fighter", swatch: NSColor(srgbRed: 0.12, green: 0.19, blue: 0.31, alpha: 1), propellerOffset: CGPoint(x: -17, y: 0)),
        PlaneColor(id: "navy-shark", name: "Navy Shark", swatch: NSColor(srgbRed: 0.12, green: 0.19, blue: 0.31, alpha: 1), propellerOffset: CGPoint(x: -17, y: 0))
    ]

    static func head(id: String?) -> Head { heads.first { $0.id == id } ?? heads[0] }
    static func color(id: String?) -> PlaneColor { colors.first { $0.id == id } ?? colors[0] }
}
