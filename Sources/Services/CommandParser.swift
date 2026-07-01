import Foundation

enum CommandParser {

    static func isStopCommand(_ text: String) -> Bool {
        let n = text.trimmingCharacters(in: .whitespaces).lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        return ["stop", "jarvis stop", "stop talking", "jarvis stop talking",
                "be quiet", "jarvis be quiet", "shut up", "jarvis shut up"].contains(n)
    }

    static func isSleepCommand(_ text: String) -> Bool {
        let l = text.lowercased()
        return l.contains("go to sleep") || l.contains("stop listening")
    }

    static func isShutdownCommand(_ text: String) -> Bool {
        let l = text.lowercased()
        return l.contains("jarvis shutdown") || l.contains("jarvis exit")
    }

    /// Mirrors handleCannedCommand() — fast, free, deterministic answers that
    /// never need to touch the model at all.
    static func cannedReply(for text: String, profile: JarvisProfile) -> String? {
        let l = text.lowercased()
        if l.contains("what is my name") || l.contains("what's my name") {
            return "Your name is \(profile.name)."
        }
        if l.contains("what time is it") || l.contains("current time") {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return "It's \(f.string(from: Date()))."
        }
        if l.contains("what's the date") || l.contains("what is today's date") {
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMMM d, yyyy"
            return "Today is \(f.string(from: Date()))."
        }
        if l.contains("who made you") || l.contains("who created you") ||
           l.contains("who built you") || l.contains("who are you") || l.contains("what are you") {
            return "I'm JARVIS, created by Kryptra."
        }
        return nil
    }

    /// iOS sandboxes apps from each other — there's no equivalent to
    /// Android's PackageManager.getInstalledApplications(), so JARVIS can't
    /// enumerate or launch arbitrary third-party apps by name the way the
    /// Android version can. This covers the common built-in apps via their
    /// public URL schemes as a reasonable substitute.
    static func systemAppURL(for spokenName: String) -> (label: String, url: URL)? {
        let name = spokenName.lowercased().trimmingCharacters(in: .whitespaces)
        let map: [String: (String, String)] = [
            "maps": ("Maps", "maps://"),
            "apple maps": ("Maps", "maps://"),
            "mail": ("Mail", "message://"),
            "messages": ("Messages", "sms:"),
            "phone": ("Phone", "tel:"),
            "camera": ("Camera", "camera://"),
            "settings": ("Settings", "App-Prefs:"),
            "calendar": ("Calendar", "calshow://"),
            "music": ("Music", "music://"),
            "photos": ("Photos", "photos-redirect://"),
            "safari": ("Safari", "https://"),
            "notes": ("Notes", "mobilenotes://"),
            "clock": ("Clock", "clock-alarm://"),
            "app store": ("App Store", "itms-apps://")
        ]
        guard let entry = map[name], let url = URL(string: entry.1) else { return nil }
        return (entry.0, url)
    }

    static func parseAppLaunchCommand(_ text: String) -> String? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        for prefix in ["open ", "launch ", "start ", "run "] {
            if lower.hasPrefix(prefix) {
                let name = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }
        return nil
    }

    /// Strips basic markdown the model might emit, mirroring stripMarkdown().
    static func stripMarkdown(_ text: String) -> String {
        var result = text
        let patterns: [(String, String)] = [
            (#"#{1,6}\s"#, ""),
            (#"\*\*(.*?)\*\*"#, "$1"),
            (#"\*(.*?)\*"#, "$1"),
            (#"`{1,3}[^`]*`{1,3}"#, ""),
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
        }
        if let regex = try? NSRegularExpression(pattern: #"^\s*[-*+]\s"#, options: .anchorsMatchLines) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Splits newly-streamed text into complete sentences ready to hand to
    /// TTS, mirroring the Android app's `sentenceEndRegex` + spoken-position
    /// tracking so nothing gets queued twice or skipped.
    static let sentenceEndRegex = try! NSRegularExpression(pattern: #"[^.!?\n]*[.!?\n]+[)\]"']*(?:\s|$)"#)
}
