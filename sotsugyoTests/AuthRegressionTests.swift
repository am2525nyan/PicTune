import XCTest
@testable import PIcTune

@MainActor
final class AuthRegressionTests: XCTestCase {
    func testSigningInAgainDoesNotOverwriteEditedProfile() {
        let existing: [String: Any] = ["name": "編集した名前", "email": "saved@example.com", "uid": "user", "custom": "keep"]
        let fields = UserAccountBootstrap.missingProfileFields(existing: existing,
            profile: UserProfile(name: "認証サービスの名前", email: "provider@example.com"), userID: "user")
        XCTAssertTrue(fields.isEmpty)
    }

    func testPartiallyCreatedProfileOnlyGetsMissingFields() {
        let fields = UserAccountBootstrap.missingProfileFields(existing: ["name": "編集した名前"],
            profile: UserProfile(name: "別名", email: "test@example.com"), userID: "user")
        XCTAssertNil(fields["name"])
        XCTAssertEqual(fields["email"] as? String, "test@example.com")
        XCTAssertEqual(fields["uid"] as? String, "user")
    }

    func testNewAccountGetsProfileAndExplicitEmptyNameIsPreserved() {
        let fields = UserAccountBootstrap.missingProfileFields(existing: [:], profile: UserProfile(), userID: "new")
        XCTAssertEqual(fields["name"] as? String, "")
        XCTAssertEqual(fields["uid"] as? String, "new")
        let existing = UserAccountBootstrap.missingProfileFields(existing: ["name": ""],
            profile: UserProfile(name: "provider"), userID: "new")
        XCTAssertNil(existing["name"])
    }

    func testAppleDeletionWaitsForSuccessfulReauthentication() async throws {
        var steps: [String] = []
        let started = expectation(description: "Reauthentication started")
        var completion: CheckedContinuation<Void, Error>?
        let task = Task {
            try await AccountDeletion.perform(reauthenticate: {
                steps.append("reauthenticate")
                try await withCheckedThrowingContinuation { continuation in
                    completion = continuation
                    started.fulfill()
                }
            }, revoke: { steps.append("revoke") }, delete: { steps.append("delete") })
        }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertEqual(steps, ["reauthenticate"])
        completion?.resume()
        try await task.value
        XCTAssertEqual(steps, ["reauthenticate", "revoke", "delete"])
    }

    func testReauthenticationFailureNeverRevokesOrDeletes() async {
        var revoked = false
        var deleted = false
        do {
            try await AccountDeletion.perform(reauthenticate: { throw AccountOperationError.unavailable },
                revoke: { revoked = true }, delete: { deleted = true })
            XCTFail("Expected failure")
        } catch { }
        XCTAssertFalse(revoked)
        XCTAssertFalse(deleted)
    }

    func testRevocationFailureNeverDeletesAccount() async {
        var deleted = false
        do {
            try await AccountDeletion.perform(reauthenticate: {},
                revoke: { throw AccountOperationError.unavailable }, delete: { deleted = true })
            XCTFail("Expected failure")
        } catch { }
        XCTAssertFalse(deleted)
    }
}
