import CryptoKit
import Foundation

enum AppleTokenService {

    // MARK: - Client Secret (JWT ES256)

    static func makeClientSecret(
        teamID: String,
        keyID: String,
        bundleID: String,
        privateKey: P256.Signing.PrivateKey
    ) throws -> String {
        let now = Date()
        let header = try JSONSerialization.data(
            withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"]
        )
        let payload = try JSONSerialization.data(withJSONObject: [
            "iss": teamID,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(now.addingTimeInterval(15_777_000).timeIntervalSince1970),
            "aud": "https://appleid.apple.com",
            "sub": bundleID,
        ])

        let headerEncoded = base64URLEncode(header)
        let payloadEncoded = base64URLEncode(payload)
        let signingInput = "\(headerEncoded).\(payloadEncoded)"

        guard let signingData = signingInput.data(using: .utf8) else {
            throw AppleTokenError.invalidInput
        }

        let signature = try privateKey.signature(for: signingData)
        let signatureEncoded = base64URLEncode(signature.rawRepresentation)

        return "\(signingInput).\(signatureEncoded)"
    }

    // MARK: - Exchange Authorization Code → Refresh Token

    static func exchangeAuthorizationCode(
        _ code: String,
        clientID: String,
        clientSecret: String
    ) async throws -> String {
        let url = URL(string: "https://appleid.apple.com/auth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
        ]
        request.httpBody = urlEncode(bodyParams).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppleTokenError.exchangeFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let refreshToken = json["refresh_token"] as? String else {
            throw AppleTokenError.exchangeFailed
        }

        return refreshToken
    }

    // MARK: - Revoke Token

    static func revokeToken(
        refreshToken: String,
        clientID: String,
        clientSecret: String
    ) async throws {
        let url = URL(string: "https://appleid.apple.com/auth/revoke")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "token": refreshToken,
            "token_type_hint": "refresh_token",
        ]
        request.httpBody = urlEncode(bodyParams).data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppleTokenError.revocationFailed
        }
    }

    // MARK: - Helpers

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func urlEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+=&")
        return params.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")
    }
}

enum AppleTokenError: Error, LocalizedError {
    case invalidInput
    case exchangeFailed
    case revocationFailed
    case missingPrivateKey

    var errorDescription: String? {
        switch self {
        case .invalidInput: "Invalid input for JWT generation."
        case .exchangeFailed: "Failed to exchange authorization code."
        case .revocationFailed: "Failed to revoke Apple token."
        case .missingPrivateKey: "Apple private key (.p8) not found in bundle."
        }
    }
}
