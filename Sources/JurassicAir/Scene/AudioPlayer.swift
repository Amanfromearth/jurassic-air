import AVFoundation
import Foundation

/// Plane audio: a continuous engine drone (plane.mp3 loop) plus a one-shot
/// signature sound from the selected `SoundPack` that fires mid-flight.
final class PlaneAudioPlayer {
    private var engine: AVAudioPlayer?
    private var voice: AVAudioPlayer?
    private var voiceWorkItem: DispatchWorkItem?
    private var engineStopWorkItem: DispatchWorkItem?

    private func prepareEngine() {
        guard let url = Bundle.module.url(forResource: "plane", withExtension: "mp3") else {
            NSLog("plane.mp3 missing from bundle resources")
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.45
            p.prepareToPlay()
            engine = p
        } catch {
            NSLog("AVAudioPlayer (engine) init failed: \(error)")
        }
    }

    private func loadVoice(_ pack: SoundPack) {
        guard let url = Bundle.module.url(forResource: pack.resource, withExtension: pack.ext) else {
            NSLog("sound pack \(pack.id) missing (\(pack.resource).\(pack.ext))")
            voice = nil
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = 0
            p.volume = 0.85
            p.prepareToPlay()
            voice = p
        } catch {
            NSLog("AVAudioPlayer (voice) init failed: \(error)")
            voice = nil
        }
    }

    /// Start the engine loop and schedule the voice one-shot to fire midway
    /// through `flightDuration` seconds.
    func start(flightDuration: TimeInterval = 8) {
        engineStopWorkItem?.cancel()
        engineStopWorkItem = nil
        guard AppSettings.shared.audioEnabled else { return }
        if engine == nil { prepareEngine() }
        engine?.setVolume(0.45, fadeDuration: 0)
        if let e = engine, !e.isPlaying {
            e.currentTime = 0
            e.volume = 0.45
            e.play()
        }

        voiceWorkItem?.cancel()
        voiceWorkItem = nil
        guard AppSettings.shared.characterSoundEnabled else {
            voice = nil
            return
        }
        // (Re)load the chosen pack each flight so a setting change takes effect
        // for the next plane without restarting the app.
        let pack = SoundCatalog.pack(id: AppSettings.shared.soundPack)
        loadVoice(pack)
        let work = DispatchWorkItem { [weak self] in
            self?.voice?.currentTime = 0
            self?.voice?.play()
        }
        voiceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + flightDuration / 2, execute: work)
    }

    /// Fade engine + stop the voice. Cancels any pending mid-flight one-shot.
    func stop() {
        voiceWorkItem?.cancel()
        voiceWorkItem = nil
        voice?.stop()
        voice = nil
        engineStopWorkItem?.cancel()

        guard let e = engine, e.isPlaying else { return }
        let fadeDuration: TimeInterval = 0.35
        e.setVolume(0, fadeDuration: fadeDuration)
        let work = DispatchWorkItem { [weak self, weak e] in
            e?.stop()
            self?.engine = nil
            self?.engineStopWorkItem = nil
        }
        engineStopWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration + 0.05, execute: work)
    }

    deinit {
        voiceWorkItem?.cancel()
        engineStopWorkItem?.cancel()
        engine?.stop()
        voice?.stop()
    }
}
