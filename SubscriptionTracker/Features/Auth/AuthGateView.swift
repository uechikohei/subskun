import AuthenticationServices
import SwiftUI
import UIKit

struct AuthGateView: View {
    @EnvironmentObject private var authStore: AuthenticationStore

    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { authStore.lastErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    authStore.lastErrorMessage = nil
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 52, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)

                Text(String(localized: "auth.title"))
                    .font(.title2.weight(.bold))

                Text(String(localized: "auth.subtitle"))
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authStore.handleAppleSignInResult(result)
                }
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(authStore.isBusy)

                Button(action: signInWithGoogle) {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text(String(localized: "auth.button.google"))
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemBackground))
                    )
                }
                .foregroundStyle(.primary)
                .disabled(authStore.isBusy)
            }
            .padding(.horizontal, 20)

            if authStore.isBusy {
                ProgressView()
                    .padding(.top, 4)
            }

            Text(String(localized: "auth.notice"))
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 28)
        .background(Color(uiColor: .systemBackground))
        .alert(
            String(localized: "common.error"),
            isPresented: isErrorPresented
        ) {
            Button(String(localized: "common.ok")) {
                authStore.lastErrorMessage = nil
            }
        } message: {
            Text(authStore.lastErrorMessage ?? String(localized: "common.unknown_error"))
        }
    }

    private func signInWithGoogle() {
        guard let viewController = UIApplication.shared.topMostViewController() else {
            authStore.lastErrorMessage = String(localized: "auth.error.presenting_context_missing")
            return
        }

        Task {
            await authStore.signInWithGoogle(presenting: viewController)
        }
    }
}
