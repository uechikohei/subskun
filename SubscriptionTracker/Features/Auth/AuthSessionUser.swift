import Foundation

enum AuthProvider: String, Codable {
    case apple
    case google

    var localizedName: String {
        switch self {
        case .apple:
            return String(localized: "auth.provider.apple")
        case .google:
            return String(localized: "auth.provider.google")
        }
    }
}

struct AuthSessionUser: Codable, Equatable {
    let id: String
    let provider: AuthProvider
    let displayName: String
    let email: String?
}
