import Foundation
import AVFoundation

/// Sentence-queue TTS, ported from the Android app's `ttsQueue` /
/// `drainTtsQueue()` logic: sentences are queued as they complete during
/// streaming and spoken back-to-back via AVSpeechSynthesizer (fully local,
/// no network) so nothing gets cut off mid-response.
@MainActor
final class TextToSpeechService: NSObject, ObservableObject {

    @Published private(set) var isSpeaking = false

    var onStartSpeaking: (() -> Void)?
    var onDoneSpeakingAll: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [String] = []

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Adds a sentence to the back of the queue and starts speaking if idle.
    func queueSpeech(_ sentence: String) {
        let clean = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        queue.append(clean)
        if !isSpeaking { drainQueue() }
    }

    /// Flushes the queue and speaks immediately (used for canned/system replies).
    func speakNow(_ text: String) {
        queue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        speak(clean)
    }

    func stop() {
        queue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func drainQueue() {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        speak(next)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }
}

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in onStartSpeaking?() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            isSpeaking = false
            if queue.isEmpty {
                onDoneSpeakingAll?()
            } else {
                drainQueue()
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
