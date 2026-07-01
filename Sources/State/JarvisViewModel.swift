import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class JarvisViewModel: ObservableObject {

    @Published var profile: JarvisProfile = ProfileStore.shared.loadProfile()
    @Published var messages: [ChatMessage] = []
    @Published var status: JarvisStatus = .idle
    @Published var voiceModeEnabled: Bool = ProfileStore.shared.voiceModeEnabled
    @Published var greetingText: String = ""
    @Published var showGreeting: Bool = false
    @Published var inputText: String = ""

    let speech = SpeechRecognizer()
    let tts = TextToSpeechService()
    let llm = LocalLLMService()

    private var history: [ConversationTurn] = []
    private var stopRequested = false
    private var ttsSpokenUpTo = 0
    private var inactivityTask: Task<Void, Never>?
    private let inactivityTimeoutSeconds: UInt64 = 30
    private var cancellables = Set<AnyCancellable>()

    init() {
        // speech/tts/llm are themselves ObservableObjects, but a @StateObject
        // only re-renders its view on ITS OWN objectWillChange — nested
        // objects' @Published changes wouldn't otherwise propagate up and
        // the UI (mic icon, status banner, etc.) would silently go stale.
        speech.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        tts.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        llm.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)

        speech.onFinalResult = { [weak self] text in
            guard let self else { return }
            Task { await self.process(text) }
        }
        tts.onStartSpeaking = { [weak self] in
            self?.status = .speaking
        }
        tts.onDoneSpeakingAll = { [weak self] in
            guard let self else { return }
            if self.status == .speaking { self.status = .idle }
        }
    }

    func start() {
        llm.loadModelIfNeeded()
        BiometricAuthService.authenticate { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.onAuthenticated()
            }
        }
    }

    private func onAuthenticated() {
        let displayName = profile.nickname.isEmpty ? profile.name : profile.nickname
        greetingText = "Welcome back, \(displayName)."
        showGreeting = true
        if voiceModeEnabled { tts.speakNow(greetingText) }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showGreeting = false
        }
    }

    // MARK: - Voice mode

    func toggleVoiceMode() {
        voiceModeEnabled.toggle()
        ProfileStore.shared.voiceModeEnabled = voiceModeEnabled
        if !voiceModeEnabled { tts.stop() }
    }

    func toggleMic() {
        if speech.isListening {
            speech.stop()
        } else {
            speech.requestAuthorization { [weak self] granted in
                guard let self, granted else { return }
                self.status = .listening
                self.speech.start()
            }
        }
    }

    func sleepNow() {
        tts.stop()
        status = .sleeping
        appendAssistant("Standing by. Tap the mic or type to wake me.")
    }

    func wakeUp() {
        status = .idle
    }

    // MARK: - Message submission

    func submitTyped() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await process(text) }
    }

    func process(_ text: String) async {
        resetInactivityTimer()
        appendUser(text)

        if CommandParser.isStopCommand(text) {
            stopRequested = true
            tts.stop()
            status = .idle
            return
        }

        if CommandParser.isSleepCommand(text) {
            appendAssistant("Standing by.")
            if voiceModeEnabled { tts.speakNow("Standing by.") }
            sleepNow()
            return
        }

        if CommandParser.isShutdownCommand(text) {
            appendAssistant("Shutting down. Goodbye.")
            if voiceModeEnabled { tts.speakNow("Shutting down. Goodbye.") }
            return
        }

        if let appName = CommandParser.parseAppLaunchCommand(text) {
            handleAppOpen(appName)
            return
        }

        if let location = WeatherService.parseLocation(from: text) {
            await handleWeather(location: location)
            return
        }

        if let canned = CommandParser.cannedReply(for: text, profile: profile) {
            appendAssistant(canned)
            if voiceModeEnabled { tts.speakNow(canned) }
            status = .idle
            return
        }

        guard case .ready = llm.loadState else {
            appendAssistant("My on-device model isn't ready yet, so I can't chat freely — but the built-in commands (time, date, your name, weather) still work.")
            status = .idle
            return
        }

        await askLLM(text)
    }

    // MARK: - App open (limited, see CommandParser.systemAppURL)

    private func handleAppOpen(_ appName: String) {
        if let (label, url) = CommandParser.systemAppURL(for: appName) {
            let reply = "Opening \(label)."
            appendAssistant(reply)
            if voiceModeEnabled { tts.speakNow(reply) }
            #if canImport(UIKit)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: voiceModeEnabled ? 1_200_000_000 : 300_000_000)
                await UIApplication.shared.open(url)
            }
            #endif
        } else {
            let reply = "I can only open built-in apps like Maps, Mail, Messages, Camera, Calendar, Music, Photos, Safari, Notes, Clock, or Settings — iOS doesn't let apps launch other third-party apps by name."
            appendAssistant(reply)
            if voiceModeEnabled { tts.speakNow(reply) }
        }
        status = .idle
    }

    // MARK: - Weather (the one feature that needs internet)

    private func handleWeather(location: String) async {
        status = .processing
        appendAssistant("Checking weather for \(location)…")
        if let result = await WeatherService.fetch(location: location) {
            updateLastAssistant("🌤 \(result)")
            if voiceModeEnabled { tts.speakNow(result) }
        } else {
            updateLastAssistant("Couldn't get weather for \"\(location)\" — that needs an internet connection, and either it's unavailable or the lookup failed.")
        }
        status = .idle
    }

    // MARK: - On-device LLM streaming

    private func askLLM(_ userText: String) async {
        status = .processing
        appendAssistant("")
        stopRequested = false
        ttsSpokenUpTo = 0
        tts.stop()

        let system = LocalLLMService.systemPrompt(profile: profile)
        var fullText = ""

        do {
            // `history` here is prior turns only — the current message is
            // passed separately as `userMessage` and appended to `history`
            // afterward, so it doesn't end up duplicated in the prompt.
            let stream = llm.streamReply(system: system, history: history, userMessage: userText)
            for try await chunk in stream {
                if stopRequested { break }
                fullText += chunk
                let clean = CommandParser.stripMarkdown(fullText)
                updateLastAssistant(clean)

                if voiceModeEnabled, clean.count > ttsSpokenUpTo {
                    let safeStart = min(ttsSpokenUpTo, clean.count)
                    let unspokenStart = clean.index(clean.startIndex, offsetBy: safeStart)
                    let unspoken = String(clean[unspokenStart...])
                    let nsRange = NSRange(unspoken.startIndex..., in: unspoken)
                    let matches = CommandParser.sentenceEndRegex.matches(in: unspoken, range: nsRange)
                    for match in matches {
                        guard let range = Range(match.range, in: unspoken) else { continue }
                        let sentence = String(unspoken[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sentence.isEmpty { tts.queueSpeech(sentence) }
                        ttsSpokenUpTo += unspoken.distance(from: unspoken.startIndex, to: range.upperBound)
                    }
                }
            }

            if !stopRequested {
                let finalText = CommandParser.stripMarkdown(fullText)
                updateLastAssistant(finalText)
                if voiceModeEnabled, finalText.count > ttsSpokenUpTo {
                    let tailStart = finalText.index(finalText.startIndex, offsetBy: min(ttsSpokenUpTo, finalText.count))
                    let tail = String(finalText[tailStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tail.isEmpty { tts.queueSpeech(tail) }
                }
            }
            history.append(ConversationTurn(role: "user", content: userText))
            history.append(ConversationTurn(role: "assistant", content: fullText))
            if history.count > 20 { history.removeFirst(history.count - 20) }
            resetInactivityTimer()
            if !voiceModeEnabled || stopRequested { status = .idle }
        } catch {
            updateLastAssistant("❌ \(error.localizedDescription)")
            status = .idle
        }
    }

    // MARK: - Transcript helpers

    private func appendUser(_ text: String) {
        messages.append(ChatMessage(role: .user, text: text))
    }

    private func appendAssistant(_ text: String) {
        messages.append(ChatMessage(role: .assistant, text: text))
    }

    private func updateLastAssistant(_ text: String) {
        if let last = messages.lastIndex(where: { $0.role == .assistant }) {
            messages[last].text = text
        } else {
            appendAssistant(text)
        }
    }

    // MARK: - Inactivity → auto-sleep, mirrors resetInactivityTimer()

    private func resetInactivityTimer() {
        inactivityTask?.cancel()
        inactivityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: (self?.inactivityTimeoutSeconds ?? 30) * 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.status != .sleeping && self.status != .processing {
                self.sleepNow()
            }
        }
    }
}
