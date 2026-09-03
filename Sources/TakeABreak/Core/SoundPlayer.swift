import AppKit

enum SoundPlayer {

    /// Held onto so the sound isn't deallocated mid-playback.
    private static var current: NSSound?

    static func play(named name: String, volume: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard let sound = NSSound(named: NSSound.Name(trimmed)) else { return }
        sound.volume = Float(min(max(volume, 0), 1))
        current = sound
        sound.stop()
        sound.play()
    }

    /// Two quick notes when a break finishes.
    static func chime(volume: Double) {
        play(named: "Tink", volume: volume)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard let sound = NSSound(named: NSSound.Name("Tink")) else { return }
            sound.volume = Float(min(max(volume, 0), 1))
            current = sound
            sound.play()
        }
    }
}
