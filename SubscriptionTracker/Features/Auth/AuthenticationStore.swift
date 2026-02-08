import AuthenticationServices
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class AuthenticationStore: ObservableObject {
    private enum Keys {
        static let currentUser = "auth.currentUser"
        static let appleIdentityCache = "auth.appleIdentityCache"
        static let emailRegistry = "auth.emailRegistry"
    }

    @Published private(set) var currentUser: AuthSessionUser?
    @Published private(set) var isBusy = false
    @Published var lastErrorMessage: String?

    private var hasRestoredSession = false
    private var emailRegistry: AuthEmailRegistry
    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.currentUser = Self.loadCurrentUser(from: defaults)
        self.emailRegistry = Self.loadEmailRegistry(from: defaults)

        if let currentUser {
            _ = registerEmailIfNeeded(for: currentUser)
        }
    }

    func restoreSessionIfNeeded() async {
        guard hasRestoredSession == false else {
            return
        }
        hasRestoredSession = true

        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            return
        }

        do {
            let googleUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let sessionUser = makeGoogleSessionUser(from: googleUser)
            if applySignedInCandidate(sessionUser) == false {
                GIDSignIn.sharedInstance.signOut()
            }
        } catch {
            GIDSignIn.sharedInstance.signOut()
            if currentUser?.provider == .google {
                applySignedInUser(nil)
            }
        }
    }

    func signInWithGoogle(presenting presentingViewController: UIViewController) async {
        lastErrorMessage = nil

        guard let configuration = googleConfigurationValues else {
            lastErrorMessage = String(localized: "auth.error.google_client_id_missing")
            return
        }

        guard ensureGoogleURLSchemeRegistered(for: configuration) else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: configuration.clientID)
            let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let sessionUser = makeGoogleSessionUser(from: signInResult.user)
            if applySignedInCandidate(sessionUser) == false {
                GIDSignIn.sharedInstance.signOut()
            }
        } catch {
            if Self.isUserCancellation(error) {
                return
            }
            lastErrorMessage = String(localized: "auth.error.google_sign_in_failed")
        }
    }

    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        lastErrorMessage = nil

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastErrorMessage = String(localized: "auth.error.apple_sign_in_failed")
                return
            }
            let sessionUser = makeAppleSessionUser(from: credential)
            _ = applySignedInCandidate(sessionUser)
        case .failure(let error):
            if Self.isUserCancellation(error) {
                return
            }
            lastErrorMessage = String(localized: "auth.error.apple_sign_in_failed")
        }
    }

    func handleOpenURL(_ url: URL) {
        _ = GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() {
        if currentUser?.provider == .google {
            GIDSignIn.sharedInstance.signOut()
        }
        applySignedInUser(nil)
    }

    private var googleConfigurationValues: GoogleConfigurationValues? {
        let serviceValues = googleConfigurationFromServicePlist()
        guard let clientID = infoStringValue(forKey: "GOOGLE_CLIENT_ID") ?? serviceValues?.clientID else {
            return nil
        }

        let reversedClientID = infoStringValue(forKey: "GOOGLE_REVERSED_CLIENT_ID")
            ?? serviceValues?.reversedClientID

        return GoogleConfigurationValues(clientID: clientID, reversedClientID: reversedClientID)
    }

    private func ensureGoogleURLSchemeRegistered(for configuration: GoogleConfigurationValues) -> Bool {
        guard let reversedClientID = configuration.reversedClientID else {
            lastErrorMessage = String(localized: "auth.error.google_reversed_client_id_missing")
            return false
        }

        guard isURLSchemeRegistered(reversedClientID) else {
            lastErrorMessage = String(localized: "auth.error.google_url_scheme_missing")
            return false
        }

        return true
    }

    private func isURLSchemeRegistered(_ scheme: String) -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }

        for urlType in urlTypes {
            guard let schemes = urlType["CFBundleURLSchemes"] as? [String] else {
                continue
            }

            if schemes.contains(where: { $0.caseInsensitiveCompare(scheme) == .orderedSame }) {
                return true
            }
        }

        return false
    }

    private func infoStringValue(forKey key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func googleConfigurationFromServicePlist() -> GoogleConfigurationValues? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dictionary = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }

        guard let clientIDRaw = dictionary["CLIENT_ID"] as? String else {
            return nil
        }

        let clientID = clientIDRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clientID.isEmpty == false else {
            return nil
        }

        let reversedClientID = (dictionary["REVERSED_CLIENT_ID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return GoogleConfigurationValues(
            clientID: clientID,
            reversedClientID: reversedClientID?.isEmpty == true ? nil : reversedClientID
        )
    }

    @discardableResult
    private func applySignedInCandidate(_ user: AuthSessionUser) -> Bool {
        switch registerEmailIfNeeded(for: user) {
        case .success:
            applySignedInUser(user)
            return true
        case .failure:
            lastErrorMessage = String(localized: "auth.error.email_already_registered")
            return false
        }
    }

    private func registerEmailIfNeeded(for user: AuthSessionUser) -> Result<Void, AuthEmailConflict> {
        let result = emailRegistry.register(
            email: user.email,
            userID: user.id,
            provider: user.provider
        )

        if case .success = result {
            persistEmailRegistry(emailRegistry)
        }

        return result
    }

    private func applySignedInUser(_ user: AuthSessionUser?) {
        currentUser = user
        persistCurrentUser(user)
    }

    private func persistCurrentUser(_ user: AuthSessionUser?) {
        guard let user else {
            defaults.removeObject(forKey: Keys.currentUser)
            return
        }
        guard let data = try? encoder.encode(user) else {
            return
        }
        defaults.set(data, forKey: Keys.currentUser)
    }

    private static func loadCurrentUser(from defaults: UserDefaults) -> AuthSessionUser? {
        guard let data = defaults.data(forKey: Keys.currentUser) else {
            return nil
        }
        return try? JSONDecoder().decode(AuthSessionUser.self, from: data)
    }

    private static func loadEmailRegistry(from defaults: UserDefaults) -> AuthEmailRegistry {
        guard let data = defaults.data(forKey: Keys.emailRegistry),
              let registry = try? JSONDecoder().decode(AuthEmailRegistry.self, from: data) else {
            return AuthEmailRegistry()
        }
        return registry
    }

    private func makeAppleSessionUser(from credential: ASAuthorizationAppleIDCredential) -> AuthSessionUser {
        let userID = credential.user
        var cache = loadAppleIdentityCache()
        var identity = cache[userID] ?? AppleIdentityCache(displayName: nil, email: nil)
        let tokenClaims = credential.identityToken.flatMap(Self.decodeAppleIdentityTokenClaims)

        if let displayName = Self.displayName(from: credential.fullName) {
            identity.displayName = displayName
        }
        if let displayName = Self.normalizedDisplayName(tokenClaims?.name) {
            identity.displayName = displayName
        }
        if let email = Self.normalizedEmail(credential.email) {
            identity.email = email
        }
        if let email = Self.normalizedEmail(tokenClaims?.email) {
            identity.email = email
        }

        cache[userID] = identity
        persistAppleIdentityCache(cache)

        return AuthSessionUser(
            id: userID,
            provider: .apple,
            displayName: identity.displayName ?? identity.email ?? String(localized: "auth.default_display_name"),
            email: identity.email
        )
    }

    private func makeGoogleSessionUser(from user: GIDGoogleUser) -> AuthSessionUser {
        let fallbackID = user.profile?.email ?? UUID().uuidString
        let userID = user.userID ?? fallbackID
        let displayName = user.profile?.name
            ?? user.profile?.email
            ?? String(localized: "auth.default_display_name")
        let email = user.profile?.email

        return AuthSessionUser(
            id: userID,
            provider: .google,
            displayName: displayName,
            email: email
        )
    }

    private func loadAppleIdentityCache() -> [String: AppleIdentityCache] {
        guard let data = defaults.data(forKey: Keys.appleIdentityCache) else {
            return [:]
        }
        return (try? decoder.decode([String: AppleIdentityCache].self, from: data)) ?? [:]
    }

    private func persistAppleIdentityCache(_ cache: [String: AppleIdentityCache]) {
        guard let data = try? encoder.encode(cache) else {
            return
        }
        defaults.set(data, forKey: Keys.appleIdentityCache)
    }

    private func persistEmailRegistry(_ registry: AuthEmailRegistry) {
        guard let data = try? encoder.encode(registry) else {
            return
        }
        defaults.set(data, forKey: Keys.emailRegistry)
    }

    private static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else {
            return nil
        }
        let formatter = PersonNameComponentsFormatter()
        let value = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func normalizedEmail(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedDisplayName(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func decodeAppleIdentityTokenClaims(from tokenData: Data) -> AppleIdentityTokenClaims? {
        guard let token = String(data: tokenData, encoding: .utf8) else {
            return nil
        }

        let parts = token.split(separator: ".")
        guard parts.count >= 2 else {
            return nil
        }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = payload.count % 4
        if remainder == 2 {
            payload += "=="
        } else if remainder == 3 {
            payload += "="
        } else if remainder == 1 {
            return nil
        }

        guard let payloadData = Data(base64Encoded: payload) else {
            return nil
        }

        return try? JSONDecoder().decode(AppleIdentityTokenClaims.self, from: payloadData)
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return true
        }
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private struct AppleIdentityCache: Codable {
    var displayName: String?
    var email: String?
}

private struct AppleIdentityTokenClaims: Decodable {
    let email: String?
    let name: String?
}

private struct GoogleConfigurationValues {
    let clientID: String
    let reversedClientID: String?
}
