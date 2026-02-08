import SwiftUI

struct AppFlowView: View {
    @EnvironmentObject private var authStore: AuthenticationStore

    var body: some View {
        Group {
            if authStore.currentUser == nil {
                AuthGateView()
            } else {
                RootTabView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: authStore.currentUser)
    }
}
