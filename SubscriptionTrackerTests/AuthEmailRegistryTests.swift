import Testing
@testable import SubsKun

struct AuthEmailRegistryTests {
    @Test
    func firstRegistrationSucceeds() {
        var registry = AuthEmailRegistry()

        let result = registry.register(
            email: "user@example.com",
            userID: "apple-user-1",
            provider: .apple
        )

        #expect(result.isSuccess)
    }

    @Test
    func sameProviderAndSameUserIDIsAllowed() {
        var registry = AuthEmailRegistry()
        _ = registry.register(
            email: "user@example.com",
            userID: "google-user-1",
            provider: .google
        )

        let result = registry.register(
            email: "user@example.com",
            userID: "google-user-1",
            provider: .google
        )

        #expect(result.isSuccess)
    }

    @Test
    func duplicateAcrossProvidersIsRejected() {
        var registry = AuthEmailRegistry()
        _ = registry.register(
            email: "user@example.com",
            userID: "apple-user-1",
            provider: .apple
        )

        let result = registry.register(
            email: "user@example.com",
            userID: "google-user-1",
            provider: .google
        )

        #expect(result.isSuccess == false)
        if case .failure(let conflict) = result {
            #expect(conflict.email == "user@example.com")
            #expect(conflict.existing.provider == .apple)
            #expect(conflict.incoming.provider == .google)
        }
    }

    @Test
    func emailIsComparedCaseInsensitively() {
        var registry = AuthEmailRegistry()
        _ = registry.register(
            email: "User@Example.com",
            userID: "apple-user-1",
            provider: .apple
        )

        let result = registry.register(
            email: "user@example.com",
            userID: "google-user-2",
            provider: .google
        )

        #expect(result.isSuccess == false)
    }

    @Test
    func emptyOrNilEmailIsIgnored() {
        var registry = AuthEmailRegistry()

        let nilResult = registry.register(
            email: nil,
            userID: "apple-user-1",
            provider: .apple
        )
        let emptyResult = registry.register(
            email: "   ",
            userID: "google-user-1",
            provider: .google
        )

        #expect(nilResult.isSuccess)
        #expect(emptyResult.isSuccess)
    }
}

private extension Result where Success == Void, Failure == AuthEmailConflict {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
