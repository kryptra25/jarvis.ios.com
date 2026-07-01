import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text.isEmpty ? "…" : message.text)
                .foregroundColor(JarvisColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? JarvisColor.bubbleUser : JarvisColor.bubbleAI)
                .cornerRadius(16)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}
