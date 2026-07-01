import Foundation
import SwiftLlama

@MainActor
final class LocalLLMService: ObservableObject {

    enum LoadState: Equatable {
        case notLoaded
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .notLoaded

    static let modelFileName = "qwen2.5-0.5b-instruct-q4_k_m"
    static let modelFileExtension = "gguf"

    private var llamaService: LlamaService?

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

        // XcodeGen may copy Resources/Models/ as either:
        //   (a) flat into the bundle root  → Bundle.main.url(forResource:withExtension:) finds it
        //   (b) as a Models/ subfolder     → we need to look one level deeper
        var modelURL = Bundle.main.url(
            forResource: Self.modelFileName,
            withExtension: Self.modelFileExtension
        )
        if modelURL == nil {
            let candidate = Bundle.main.bundleURL
                .appendingPathComponent("Models")
                .appendingPathComponent("\(Self.modelFileName).\(Self.modelFileExtension)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                modelURL = candidate
            }
        }

        guard let url = modelURL else {
            loadState = .failed("Model file not found in app bundle. Make sure scripts/download_model.sh ran before building.")
            return
        }

        llamaService = LlamaService(
            modelUrl: url,
            config: .init(batchSize: 256, maxTokenCount: 2048, useGPU: true)
        )
        loadState = .ready
    }

    func streamReply(system: String, history: [ConversationTurn], userMessage: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let llamaService else {
                    continuation.finish(throwing: LLMError.notReady)
                    return
                }

                var messages: [LlamaChatMessage] = [
                    LlamaChatMessage(role: .system, content: system)
                ]
                for turn in history.suffix(12) where turn.role != "system" {
                    let role: LlamaChatMessage.Role = turn.role == "user" ? .user : .assistant
                    messages.append(LlamaChatMessage(role: role, content: turn.content))
                }
                messages.append(LlamaChatMessage(role: .user, content: userMessage))

                do {
                    let stream = try await llamaService.streamCompletion(
                        of: messages,
                        samplingConfig: .init(temperature: 0.7, seed: 42)
                    )
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
}
