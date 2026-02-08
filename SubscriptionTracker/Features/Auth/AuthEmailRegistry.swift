import Foundation

struct AuthEmailRegistry: Codable, Equatable {
    struct Account: Codable, Equatable {
        let userID: String
        let provider: AuthProvider
    }

    private(set) var accountsByEmail: [String: Account] = [:]

    mutating func register(
        email: String?,
        userID: String,
        provider: AuthProvider
    ) -> Result<Void, AuthEmailConflict> {
        guard let normalizedEmail = Self.normalize(email) else {
            return .success(())
        }

        let incoming = Account(userID: userID, provider: provider)

        if let existing = accountsByEmail[normalizedEmail] {
            if existing == incoming {
                return .success(())
            }
            return .failure(
                AuthEmailConflict(
                    email: normalizedEmail,
                    existing: existing,
                    incoming: incoming
                )
            )
        }

        accountsByEmail[normalizedEmail] = incoming
        return .success(())
    }

    static func normalize(_ email: String?) -> String? {
        guard let email else {
            return nil
        }
        let trimmed = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct AuthEmailConflict: Error, Equatable {
    let email: String
    let existing: AuthEmailRegistry.Account
    let incoming: AuthEmailRegistry.Account
}
