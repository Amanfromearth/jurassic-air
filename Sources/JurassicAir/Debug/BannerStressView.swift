#if DEBUG
import AppKit
import SwiftUI
import SpriteKit

/// Isolated development screen: actual banner renderer, synthetic events,
/// local preferences, and no calendar access, schedules, audio, or saved edits.
struct BannerStressView: View {
    @StateObject private var settings = AppSettings(defaults: UserDefaults(suiteName: "jurassicair.banner-stress")!)
    @AppStorage("dataset", store: UserDefaults(suiteName: "jurassicair.banner-stress")) private var dataset = "Demo data"
    @State private var width: CGFloat = 720
    @State private var zoom: CGFloat = 1
    @State private var dark = false
    @State private var wave = false

    private var samples: [BannerStressFixtures.Sample] {
        switch dataset {
        case "Worst case": return BannerStressFixtures.worst
        case "Empty": return BannerStressFixtures.empty
        case "One": return [BannerStressFixtures.worst[2]]
        default: return BannerStressFixtures.demo
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Banner stress test").font(.title2.bold())
                Spacer()
                Toggle("Dark", isOn: $dark)
                Toggle("Wave", isOn: $wave)
            }.padding()
            HStack {
                Picker("Font", selection: $settings.bannerFont) {
                    ForEach(FontCatalog.fonts) { Text($0.name).tag($0.id) }
                }
                Picker("Theme", selection: $settings.bannerTheme) {
                    ForEach(ThemeCatalog.themes) { Text($0.name).tag($0.id) }
                }
                Picker("Container", selection: $width) {
                    Text("320 pt").tag(CGFloat(320))
                    Text("720 pt").tag(CGFloat(720))
                    Text("2560 pt").tag(CGFloat(2560))
                }
                Picker("Zoom", selection: $zoom) {
                    Text("100%").tag(CGFloat(1))
                    Text("200%").tag(CGFloat(2))
                }
            }.padding(.horizontal).padding(.bottom)
            HStack {
                Text("Size")
                Slider(value: $settings.displayScale, in: 0.2...1.5)
                Text(settings.displayScale, format: .number.precision(.fractionLength(2))).monospacedDigit()
                Text("Wave height")
                Slider(value: $settings.bannerAmplitude, in: 0...4)
            }.padding(.horizontal).padding(.bottom)
            Divider()
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(samples) { sample in
                        let scale = CGFloat(settings.displayScale) * zoom
                        let banner = BannerRibbon(text: sample.event.title.uppercased(), createsTexture: false, settings: settings)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(sample.id).font(.headline)
                            Text(sample.title.isEmpty ? "(empty title)" : sample.title)
                                .font(.caption).foregroundStyle(.secondary)
                                .lineLimit(3).help(sample.title)
                            BannerStressRender(title: sample.event.title, settings: settings, scale: scale, wave: wave)
                                .frame(width: banner.size.width * scale, height: banner.size.height * scale)
                                .help(sample.title)
                        }
                        .padding(12)
                        .frame(width: max(width, banner.size.width * scale + 24), alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                }.padding()
            }
            Divider()
            Picker("Data", selection: $dataset) {
                ForEach(["Demo data", "Worst case", "Empty", "One"], id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented).frame(maxWidth: 440).padding(12)
        }
        .frame(minWidth: 900, minHeight: 620)
        .preferredColorScheme(dark ? .dark : .light)
    }
}

private struct BannerStressRender: View {
    let title: String
    @ObservedObject var settings: AppSettings
    let scale: CGFloat
    let wave: Bool

    var body: some View {
        let banner = BannerRibbon(text: title.uppercased(), settings: settings)
        let size = CGSize(width: banner.size.width * scale, height: banner.size.height * scale)
        if wave {
            let scene = StressScene(size: size)
            let _ = configure(scene: scene, banner: banner, size: size)
            SpriteView(scene: scene, preferredFramesPerSecond: 20, options: [.allowsTransparency])
        } else if let image = banner.flatImage {
            Image(decorative: image, scale: 1)
                .interpolation(.none).resizable()
                .frame(width: size.width, height: size.height)
        }
    }

    private func configure(scene: StressScene, banner: BannerRibbon, size: CGSize) {
        banner.setScale(scale)
        banner.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        banner.position = CGPoint(x: size.width / 2, y: size.height / 2)
        scene.banner = banner
        scene.backgroundColor = .clear
        scene.scaleMode = .aspectFit
        scene.addChild(banner)
    }

    private final class StressScene: SKScene {
        var banner: BannerRibbon?
        override func update(_ currentTime: TimeInterval) {
            banner?.tick(currentTime: currentTime)
        }
    }
}
#endif
