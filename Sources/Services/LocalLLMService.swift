import Foundation
import SwiftLlama

/// Wraps the bundled GGUF model and exposes simple streaming chat generation.
///
/// The Android app talked to Ollama over the network (`JarvisApp.ollamaUrl`).
/// Here, the model ships *inside the app bundle* (see Resources/Models) and
/// runs entirely on-device via llama.cpp (through the SwiftLlama package).
/// No network call is made for AI responses, ever — that's the whole point
/// of the offline iOS port.
///
/// NOTE: SwiftLlama's public API is small and may evolve. If a future
/// version of the package renames `start(for:)`, this is the one file that
/// needs updating — everything else in the app talks to `LocalLLMService`,
/// not to SwiftLlama directly.
@MainActor
final class LocalLLMService: ObservableObject {

    enum LoadState: Equatable {
        case notLoaded
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .notLoaded

    /// Name of the bundled model file (without extension is filled in by the
    /// build pipeline — see scripts/download_model.sh and the GitHub Actions
    /// workflow). Keep this in sync with project.yml's resources entry.
    static let modelFileName = "qwen2.5-0.5b-instruct-q4_k_m"
    static let modelFileExtension = "gguf"

    private var llama: SwiftLlama?

    /// Short system prompt — ported from JarvisApp.systemPrompt() in the
    /// Android app, with the network/host detail removed since there's no
    /// network round-trip here.
    static func systemPrompt(profile: JarvisProfile) -> String {
        let addressedAs = profile.nickname.isEmpty ? "" : " You call them \(profile.nickname)."
        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)
        return """
        You are JARVIS (Just A Rather Very Intelligent System), a personal AI assistant created exclusively by Kryptra.
        You were built from the ground up by Kryptra's engineering team. You are not made by Anthropic, OpenAI, Google, Meta, or any other company. You are entirely a Kryptra product.
        If anyone asks who made you, who created you, or what you are based on, the answer is always: Kryptra created you.
        You run fully offline on a mobile phone with a small on-device model, so keep responses short, conversational, and to the point.
        The user's name is \(profile.name).\(addressedAs)
        Never use markdown formatting. Today's date: \(dateString).
        """
    }

    func loadModelIfNeeded() {
        guard case .notLoaded = loadState else { return }
        loadState = .loading
        guard let url = Bundle.main.url(forResource: Self.modelFileName, withExtension: Self.modelFileExtension) else {
            loadState = .failed("The on-device model file wasn't found in the app bundle. Rebuild following the README's model-download step before archiving.")
            return
        }
        do {
            llama = try SwiftLlama(modelPath: url.path)
            loadState = .ready
        } catch {
            loadState = .failed("Couldn't load the on-device model: \(error.localizedDescription)")
        }
    }

    /// Builds a ChatML-style prompt (the format Qwen2.5-Instruct expects) and
    /// streams the model's reply back token-by-token via the returned
    /// AsyncThrowingStream, so the UI/TTS can consume partial text exactly
    /// like the Android app consumed Ollama's SSE stream.
    func streamReply(system: String, history: [ConversationTurn], userMessage: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let llama else {
                    continuation.finish(throwing: LLMError.notReady)
                    return
                }
                let prompt = Self.buildChatMLPrompt(system: system, history: history, userMessage: userMessage)
                do {
                    let stream = await llama.start(for: prompt)
                    for try await token in stream {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    enum LLMError: LocalizedError {
        case notReady
        var errorDescription: String? { "The on-device model isn't loaded yet." }
    }

    /// Qwen2.5's chat template. Trimmed to the last few turns to keep the
    /// prompt small — this is a 0.5B model on a phone, not a server.
    private static func buildChatMLPrompt(system: String, history: [ConversationTurn], userMessage: String) -> String {
        var text = "<|im_start|>system\n\(system)<|im_end|>\n"
        for turn in history.suffix(12) where turn.role != "system" {
            text += "<|im_start|>\(turn.role)\n\(turn.content)<|im_end|>\n"
        }
        text += "<|im_start|>user\n\(userMessage)<|im_end|>\n<|im_start|>assistant\n"
        return text
    }
}
