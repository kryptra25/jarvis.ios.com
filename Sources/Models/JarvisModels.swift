import Foundation

/// Mirrors `JarvisProfile` from the Android app's MainActivity.kt
struct JarvisProfile: Codable, Equatable {
    var name: String
    var nickname: String
    var assistantName: String   // was "wakeWord" on Android; here it's just the assistant's name

    static let empty = JarvisProfile(name: "", nickname: "", assistantName: "Jarvis")
}

/// Mirrors `JarvisStatus` enum from the Android app
enum JarvisStatus: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case sleeping
    case modelUnavailable

    var label: String {
        switch self {
        case .idle:             return "● READY"
        case .listening:        return "◉ LISTENING"
        case .processing:       return "◌ PROCESSING"
        case .speaking:         return "▶ SPEAKING"
        case .sleeping:         return "⏸ SLEEPING"
        case .modelUnavailable: return "✕ MODEL UNAVAILABLE"
        }
    }

    var color: StatusColorToken {
        switch self {
        case .idle:             return .accentBlue
        case .listening:        return .statusListening
        case .processing:       return .statusProcessing
        case .speaking:         return .statusSpeaking
        case .sleeping:         return .statusSleeping
        case .modelUnavailable: return .statusOffline
        }
    }
}

/// Plain Swift enum (no SwiftUI import needed here) describing which named
/// color a status maps to. The actual Color values live in Theme.swift's
/// JarvisColor enum to keep this model file UI-framework-agnostic.
enum StatusColorToken {
    case accentBlue, statusListening, statusProcessing, statusSpeaking, statusSleeping, statusOffline
}

/// A single line in the on-screen transcript.
struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

/// One turn for the LLM's own context window (separate from the UI transcript
/// because the UI may show extra system messages the model never sees).
struct ConversationTurn {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}
