import SwiftUI

struct SetupView: View {
    let onFinished: () -> Void

    @State private var name = ""
    @State private var nickname = ""
    @State private var assistantName = ""
    @State private var nameError = false

    var body: some View {
        ZStack {
            JarvisColor.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("JARVIS")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(JarvisColor.accentBlue)
                        Text("Let's get you set up.")
                            .font(.subheadline)
                            .foregroundColor(JarvisColor.textSecondary)
                    }
                    .padding(.top, 40)

                    field(title: "Your name", text: $name, placeholder: "e.g. Alex", error: nameError ? "Please enter your name" : nil)
                    field(title: "What should JARVIS call you? (optional)", text: $nickname, placeholder: "e.g. boss")
                    field(title: "Assistant's name (optional)", text: $assistantName, placeholder: "Jarvis")

                    Button(action: finish) {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(JarvisColor.accentBlue)
                            .foregroundColor(JarvisColor.bgPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)

                    Text("Everything runs on this phone. Voice recognition, text-to-speech, and the AI model all work fully offline — no account, no internet connection, no subscription.")
                        .font(.footnote)
                        .foregroundColor(JarvisColor.textSecondary)
                        .padding(.top, 4)
                }
                .padding(24)
            }
        }
    }

    private func field(title: String, text: Binding<String>, placeholder: String, error: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(JarvisColor.textSecondary)
            TextField(placeholder, text: text)
                .foregroundColor(JarvisColor.textPrimary)
                .padding(12)
                .background(JarvisColor.bgInput)
                .cornerRadius(10)
            if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(JarvisColor.statusOffline)
            }
        }
    }

    private func finish() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameError = true
            return
        }
        let profile = JarvisProfile(
            name: trimmedName,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            assistantName: assistantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jarvis" : assistantName
        )
        ProfileStore.shared.save(profile: profile)
        onFinished()
    }
}
