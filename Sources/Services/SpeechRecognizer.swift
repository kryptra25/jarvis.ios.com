import Foundation
import Speech
import AVFoundation

/// Tap-to-talk speech recognition using Apple's on-device Speech framework.
/// `requiresOnDeviceRecognition = true` keeps recognition fully offline —
/// no audio ever leaves the phone. (On-device dictation needs the language
/// pack installed; iOS prompts for this automatically the first time.)
///
/// This intentionally mirrors the "simple v1.0-style toggle" the Android app
/// settled on: one boolean, tap to start, tap (or silence) to stop, no
/// debounce or state machine — that's the version that worked reliably.
@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {

    @Published private(set) var isListening = false
    @Published private(set) var isAvailable = true
    @Published var transcript = ""

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var onFinalResult: ((String) -> Void)?

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
        isAvailable = recognizer?.isAvailable ?? false
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                let speechOK = authStatus == .authorized
                AVAudioApplication.requestRecordPermission { micOK in
                    DispatchQueue.main.async { completion(speechOK && micOK) }
                }
            }
        }
    }

    func toggle() {
        if isListening {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            isAvailable = false
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            isAvailable = false
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            isAvailable = false
            return
        }

        isListening = true
        transcript = ""

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in self.transcript = result.bestTranscription.formattedString }
                if result.isFinal {
                    let finalText = result.bestTranscription.formattedString
                    Task { @MainActor in
                        self.stop()
                        self.onFinalResult?(finalText)
                    }
                }
            }
            if error != nil {
                Task { @MainActor in self.stop() }
            }
        }
    }

    func stop() {
        guard isListening else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
