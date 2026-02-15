import SwiftData
import SwiftUI

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authStore: AuthenticationStore
    @EnvironmentObject private var settings: AppSettings
    @State private var isSignOutDialogPresented = false
    @State private var isDeleteAccountDialogPresented = false

    private var user: AuthSessionUser? {
        authStore.currentUser
    }

    var body: some View {
        List {
            Section(String(localized: "auth.account.section.current")) {
                LabeledContent(String(localized: "auth.account.provider")) {
                    Text(user?.provider.localizedName ?? String(localized: "settings.account.not_signed_in"))
                        .foregroundStyle(.secondary)
                }

                LabeledContent(String(localized: "auth.account.name")) {
                    Text(user?.displayName ?? String(localized: "settings.account.not_signed_in"))
                        .foregroundStyle(.secondary)
                }

                LabeledContent(String(localized: "auth.account.email")) {
                    Text(emailDisplayText)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    isSignOutDialogPresented = true
                } label: {
                    Text(String(localized: "auth.account.sign_out"))
                }
            }

            Section {
                Button(role: .destructive) {
                    isDeleteAccountDialogPresented = true
                } label: {
                    Text(String(localized: "auth.account.delete_account"))
                }
            }
        }
        .navigationTitle(String(localized: "auth.account.navigation_title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            String(localized: "auth.account.sign_out.confirm_title"),
            isPresented: $isSignOutDialogPresented,
            titleVisibility: .visible
        ) {
            Button(String(localized: "auth.account.sign_out"), role: .destructive) {
                authStore.signOut()
                dismiss()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "auth.account.sign_out.confirm_message"))
        }
        .confirmationDialog(
            String(localized: "auth.account.delete_account.confirm_title"),
            isPresented: $isDeleteAccountDialogPresented,
            titleVisibility: .visible
        ) {
            Button(String(localized: "auth.account.delete_account"), role: .destructive) {
                authStore.deleteAccount(modelContext: modelContext, settings: settings)
                dismiss()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "auth.account.delete_account.confirm_message"))
        }
    }

    private var emailDisplayText: String {
        if let email = user?.email {
            return email
        }
        if user?.provider == .apple {
            return String(localized: "auth.account.email.apple_unavailable")
        }
        return String(localized: "auth.account.email.empty")
    }
}
