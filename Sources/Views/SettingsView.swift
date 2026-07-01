import SwiftUI

struct SettingsView: View {
    @Binding var profile: JarvisProfile
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var nickname: String = ""
    @State private var assistantName: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                JarvisColor.bgPrimary.ignoresSafeArea()
                Form {
                    Section(header: Text("Profile").foregroundColor(JarvisColor.textSecondary)) {
                        TextField("Your name", text: $name)
                        TextField("Nickname (optional)", text: $nickname)
                        TextField("Assistant name", text: $assistantName)
                    }
                    Section(header: Text("On-device AI").foregroundColor(JarvisColor.textSecondary)) {
                        HStack {
                            Text("Model")
                            Spacer()
                            Text(LocalLLMService.modelFileName)
                                .foregroundColor(JarvisColor.textSecondary)
                        }
                        Text("This model runs entirely on your phone. No data is sent anywhere, and the app works with Wi-Fi and cellular both off.")
                            .font(.footnote)
                            .foregroundColor(JarvisColor.textSecondary)
                    }
                    Section {
                        Text("Weather lookups are the only feature that needs an internet connection — there's no offline source for live weather data. Everything else (chat, voice, your built-in commands) works with no connection at all.")
                            .font(.footnote)
                            .foregroundColor(JarvisColor.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("JARVIS Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            name = profile.name
            nickname = profile.nickname
            assistantName = profile.assistantName
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let updated = JarvisProfile(
            name: trimmedName,
            nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            assistantName: assistantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Jarvis" : assistantName
        )
        ProfileStore.shared.save(profile: updated)
        profile = updated
        dismiss()
    }
}
