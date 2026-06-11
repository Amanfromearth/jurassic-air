import Foundation

/// Mid-flight one-shot sound pack — pairs with a head. The engine drone
/// (`plane.mp3`) loops on top regardless of this choice.
struct SoundPack: Identifiable, Hashable {
    let id: String
    let name: String
    let resource: String   // resource basename (no extension)
    let ext: String        // file extension
}

enum SoundCatalog {
    static let packs: [SoundPack] = [
        SoundPack(id: "quack",    name: "Quack",    resource: "quack",  ext: "wav"),
        SoundPack(id: "corgi",    name: "Corgi",    resource: "dog",    ext: "wav"),
        SoundPack(id: "dino",     name: "Dino",     resource: "dino",   ext: "wav"),
        SoundPack(id: "pigeon",   name: "Pigeon",   resource: "pigeon", ext: "wav"),
        SoundPack(id: "capybara", name: "Capybara", resource: "capy",   ext: "wav")
    ]

    static func pack(id: String?) -> SoundPack {
        packs.first { $0.id == id } ?? packs[0]
    }
}
