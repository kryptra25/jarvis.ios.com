import Foundation

/// Mirrors the SharedPreferences keys used throughout JarvisApp on Android,
/// minus the Ollama host/port/model fields (not needed — the model is bundled
/// on-device here instead of reached over the network).
final class ProfileStore {
    static let shared = ProfileStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let userName       = "jarvis_user_name"
        static let nickname       = "jarvis_nickname"
        static let assistantName  = "jarvis_assistant_name"
        static let voiceMode      = "jarvis_voice_mode"
        static let setupComplete  = "jarvis_setup_complete"
    }

    var isSetupComplete: Bool {
        defaults.bool(forKey: Key.setupComplete)
    }

    var voiceModeEnabled: Bool {
        get { defaults.bool(forKey: Key.voiceMode) }
        set { defaults.set(newValue, forKey: Key.voiceMode) }
    }

    func loadProfile() -> JarvisProfile {
        JarvisProfile(
            name: defaults.string(forKey: Key.userName) ?? "",
            nickname: defaults.string(forKey: Key.nickname) ?? "",
            assistantName: defaults.string(forKey: Key.assistantName) ?? "Jarvis"
        )
    }

    func save(profile: JarvisProfile) {
        defaults.set(profile.name, forKey: Key.userName)
        defaults.set(profile.nickname, forKey: Key.nickname)
        defaults.set(profile.assistantName.isEmpty ? "Jarvis" : profile.assistantName, forKey: Key.assistantName)
        defaults.set(true, forKey: Key.setupComplete)
    }
}
