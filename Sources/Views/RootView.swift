import SwiftUI

struct RootView: View {
    @State private var setupComplete = ProfileStore.shared.isSetupComplete

    var body: some View {
        Group {
            if setupComplete {
                MainChatView(viewModel: JarvisViewModel())
            } else {
                SetupView(onFinished: { setupComplete = true })
            }
        }
    }
}
