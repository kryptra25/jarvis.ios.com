import Foundation

/// Ported from `handleWeather()` / `parseWeatherCommand()` in the Android app.
/// This is the single feature in the app that requires an internet
/// connection — there's no way to know live weather without reaching a
/// weather service. It fails gracefully and tells the user plainly when
/// there's no connection, rather than pretending to be fully offline here.
enum WeatherService {
    static func parseLocation(from text: String) -> String? {
        let lower = text.lowercased()
        let patterns = [
            #"weather (?:in|for|at) (.+)"#,
            #"what(?:'s| is) the weather (?:in|for|at|like in) (.+)"#,
            #"how(?:'s| is) the weather (?:in|for|at) (.+)"#,
            #"weather (.+)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(lower.startIndex..., in: lower)
            if let match = regex.firstMatch(in: lower, range: range),
               let group = Range(match.range(at: 1), in: lower) {
                var loc = String(lower[group]).trimmingCharacters(in: .whitespaces)
                loc = loc.trimmingCharacters(in: CharacterSet(charactersIn: "?."))
                if !loc.isEmpty && loc.count < 60 { return loc }
            }
        }
        return nil
    }

    static func fetch(location: String) async -> String? {
        guard let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        guard let url = URL(string: "https://wttr.in/\(encoded)?format=%l:+%C,+%t+feels+like+%f,+humidity+%h,+wind+%w") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("JarvisIOS/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
