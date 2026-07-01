import Foundation
import LocalAuthentication

/// Mirrors `authenticate()` / `onAuthenticated()` in the Android app: try
/// biometrics (or device passcode as a fallback), but never hard-block the
/// user if biometrics aren't available — just like the Android version falls
/// through to `onAuthenticated()` when `canAuthenticate` fails.
enum BiometricAuthService {
    static func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics/passcode configured on this device — behave like
            // the Android app does and just let the user in.
            completion(true)
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Verify your identity to unlock JARVIS"
        ) { success, _ in
            DispatchQueue.main.async {
                // Mirrors the Android behaviour: both success AND error paths
                // call onAuthenticated() — a failed/cancelled biometric prompt
                // doesn't lock the user out of their own phone's assistant.
                completion(true)
            }
        }
    }
}
