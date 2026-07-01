import SwiftUI

struct MainChatView: View {
    @StateObject var viewModel: JarvisViewModel
    @State private var showSettings = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            JarvisColor.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.showGreeting {
                    Text(viewModel.greetingText)
                        .font(.subheadline)
                        .foregroundColor(JarvisColor.accentBlue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(JarvisColor.bgSecondary)
                        .transition(.opacity)
                }

                if case .failed(let message) = viewModel.llm.loadState {
                    modelBanner(message: message)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let last = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                inputBar
            }
        }
        .onAppear { viewModel.start() }
        .sheet(isPresented: $showSettings) {
            SettingsView(profile: $viewModel.profile)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JARVIS")
                    .font(.headline)
                    .foregroundColor(JarvisColor.textPrimary)
                Text(viewModel.status.label)
                    .font(.caption2)
                    .foregroundColor(swiftUIColor(for: viewModel.status))
            }
            Spacer()
            Button(action: viewModel.toggleVoiceMode) {
                Image(systemName: viewModel.voiceModeEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundColor(viewModel.voiceModeEnabled ? JarvisColor.accentBlue : JarvisColor.textSecondary)
            }
            Button(action: viewModel.sleepNow) {
                Image(systemName: "moon.fill")
                    .foregroundColor(JarvisColor.textSecondary)
            }
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(JarvisColor.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(JarvisColor.bgSecondary)
    }

    private func modelBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("On-device model unavailable")
                .font(.caption.bold())
                .foregroundColor(JarvisColor.statusOffline)
            Text(message)
                .font(.caption2)
                .foregroundColor(JarvisColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(JarvisColor.bgOfflineBanner)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message JARVIS…", text: $viewModel.inputText, axis: .vertical)
                .focused($inputFocused)
                .foregroundColor(JarvisColor.textPrimary)
                .padding(10)
                .background(JarvisColor.bgInput)
                .cornerRadius(10)
                .onSubmit { viewModel.submitTyped() }

            Button(action: { viewModel.toggleMic() }) {
                Image(systemName: viewModel.speech.isListening ? "mic.fill" : "mic")
                    .foregroundColor(viewModel.speech.isListening ? JarvisColor.statusListening : JarvisColor.textSecondary)
                    .frame(width: 36, height: 36)
            }

            Button(action: { viewModel.submitTyped() }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(JarvisColor.accentBlue)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(12)
        .background(JarvisColor.bgSecondary)
    }

    private func swiftUIColor(for status: JarvisStatus) -> Color {
        switch status.color {
        case .accentBlue: return JarvisColor.accentBlue
        case .statusListening: return JarvisColor.statusListening
        case .statusProcessing: return JarvisColor.statusProcessing
        case .statusSpeaking: return JarvisColor.statusSpeaking
        case .statusSleeping: return JarvisColor.statusSleeping
        case .statusOffline: return JarvisColor.statusOffline
        }
    }
}
