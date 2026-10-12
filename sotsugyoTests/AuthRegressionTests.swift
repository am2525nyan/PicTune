import XCTest
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices
@testable import PIcTune

@MainActor
final class AuthRegressionTests: XCTestCase {
    func testLinkingFillsAnonymousEmailWithoutOverwritingEditedName() {
        let fields = UserAccountBootstrap.missingProfileFields(existing: ["uid": "anon", "name": "自分の名前", "email": ""],
            profile: UserProfile(name: "Googleの名前", email: "linked@example.com"), userID: "anon")
        XCTAssertEqual(fields["email"] as? String, "linked@example.com")
        XCTAssertNil(fields["name"])
        XCTAssertNil(fields["uid"])
        XCTAssertEqual(UserProfile(documentData: ["email": ""], fallbackEmail: "linked@example.com").email,
                       "linked@example.com")
    }

    func testConflictExplainsThatTheCurrentDataIsPreserved() {
        for code in [AuthErrorCode.credentialAlreadyInUse, .emailAlreadyInUse, .accountExistsWithDifferentCredential] {
            let message = AccountLinkingModel.message(for: NSError(domain: AuthErrorDomain, code: code.rawValue))
            XCTAssertTrue(message.contains("現在のデータはそのまま保持"))
            XCTAssertTrue(message.contains("設定の「アカウント」からログイン"))
        }
    }
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

/// Uses only the local Auth (9099) and Firestore (8187) emulators, with production rules.
@MainActor
final class AnonymousAuthIntegrationTests: XCTestCase {
    private var auth: Auth!
    private var database: Firestore!

    override func setUp() async throws {
        for port in [9099, 8187] {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/")!)
            request.timeoutInterval = 1
            do { _ = try await URLSession.shared.data(for: request) }
            catch { throw XCTSkip("Start local Auth/Firestore emulators on ports 9099/8187") }
        }
        let name = "PicTuneAnonymousIntegration"
        if FirebaseApp.app(name: name) == nil {
            let options = FirebaseOptions(googleAppID: "1:123456789:ios:abcdef", gcmSenderID: "123456789")
            options.projectID = "demo-pictune-auth"
            options.apiKey = "emulator-only"
            FirebaseApp.configure(name: name, options: options)
            let app = FirebaseApp.app(name: name)!
            Auth.auth(app: app).useEmulator(withHost: "127.0.0.1", port: 9099)
            let db = Firestore.firestore(app: app)
            let settings = db.settings
            settings.host = "127.0.0.1:8187"
            settings.isSSLEnabled = false
            settings.cacheSettings = MemoryCacheSettings()
            db.settings = settings
        }
        let app = FirebaseApp.app(name: name)!
        auth = Auth.auth(app: app)
        database = Firestore.firestore(app: app)
        try auth.signOut()
    }

    override func tearDown() async throws { try auth?.signOut() }

    func testFirstLaunchCreatesAnonymousUserAndLogoutDoesNotCreateAnother() async throws {
        let manager = AuthenticationManager(auth: auth, saveProfile: { _, _ in })
        try await waitUntil { !manager.isStartingSession }
        XCTAssertTrue(auth.currentUser?.isAnonymous == true)
        let uid = try XCTUnwrap(manager.userID)
        await manager.startAnonymously()
        XCTAssertEqual(auth.currentUser?.uid, uid)
        try auth.signOut()
        try await waitUntil { manager.userID == nil }
        XCTAssertFalse(manager.isStartingSession)
        XCTAssertNil(auth.currentUser)
        await manager.startAnonymously()
        XCTAssertTrue(auth.currentUser?.isAnonymous == true)
        XCTAssertNotEqual(auth.currentUser?.uid, uid)
    }

    func testExistingEmailUserIsRestoredWithoutAnonymousReplacement() async throws {
        let existing = try await auth.createUser(withEmail: uniqueEmail(), password: "Existing123!")
        let manager = AuthenticationManager(auth: auth, saveProfile: { _, _ in })
        try await waitUntil { !manager.isStartingSession }
        XCTAssertEqual(manager.userID, existing.user.uid)
        XCTAssertFalse(try XCTUnwrap(auth.currentUser).isAnonymous)
    }

    func testEmailLinkPreservesUIDPhotosMusicLetterAndEditedNameAcrossLogin() async throws {
        let anonymous = try await auth.signInAnonymously()
        let uid = anonymous.user.uid
        try await UserAccountBootstrap.save(userID: uid, profile: UserProfile(), database: database)
        let user = database.collection("users").document(uid)
        let info = user.collection("personal").document("info")
        let folder = user.collection("folders").document("all")
        try await info.updateData(["name": "編集した名前"])
        try await folder.updateData(["letter": "大切な手紙"])
        let file = "test-\(UUID().uuidString).jpg"
        try await database.collection("imageOwners").document(file).setData(["ownerID": uid])
        let photo = folder.collection("photos").document("photo")
        try await photo.setData(["url": file, "trackName": "思い出の曲", "id": "music-id"])
        let email = uniqueEmail()
        let model = AccountLinkingModel(auth: auth)
        let linked = await model.linkEmail(email: email, password: "Linked123!")
        XCTAssertTrue(linked, model.errorMessage ?? "")
        XCTAssertEqual(auth.currentUser?.uid, uid)
        XCTAssertFalse(try XCTUnwrap(auth.currentUser).isAnonymous)
        try await UserAccountBootstrap.save(userID: uid, profile: UserProfile(name: "認証名", email: email), database: database)
        try auth.signOut()
        let restored = try await auth.signIn(withEmail: email, password: "Linked123!")
        XCTAssertEqual(restored.user.uid, uid)
        let profile = try await info.getDocument(source: .server)
        XCTAssertEqual(profile.data()?["name"] as? String, "編集した名前")
        XCTAssertEqual(profile.data()?["email"] as? String, email)
        let savedFolder = try await folder.getDocument(source: .server)
        XCTAssertEqual(savedFolder.data()?["letter"] as? String, "大切な手紙")
        let savedPhoto = try await photo.getDocument(source: .server)
        XCTAssertEqual(savedPhoto.data()?["url"] as? String, file)
        XCTAssertEqual(savedPhoto.data()?["trackName"] as? String, "思い出の曲")
    }

    func testExistingEmailConflictKeepsAnonymousSessionAndAllowsExplicitExistingLogin() async throws {
        let email = uniqueEmail()
        let existing = try await auth.createUser(withEmail: email, password: "Existing123!")
        try auth.signOut()
        let anonymous = try await auth.signInAnonymously()
        let model = AccountLinkingModel(auth: auth)
        let linked = await model.linkEmail(email: email, password: "Existing123!")
        XCTAssertFalse(linked)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(auth.currentUser?.uid, anonymous.user.uid)
        XCTAssertTrue(try XCTUnwrap(auth.currentUser).isAnonymous)
        let restored = try await auth.signIn(withEmail: email, password: "Existing123!")
        XCTAssertEqual(restored.user.uid, existing.user.uid)
    }

    func testStaleLinkScreenCannotModifyAnotherUser() async throws {
        _ = try await auth.signInAnonymously()
        let model = AccountLinkingModel(auth: auth)
        try auth.signOut()
        let other = try await auth.signInAnonymously()
        let linked = await model.linkEmail(email: uniqueEmail(), password: "Linked123!")
        XCTAssertFalse(linked)
        XCTAssertEqual(auth.currentUser?.uid, other.user.uid)
        XCTAssertTrue(try XCTUnwrap(auth.currentUser).isAnonymous)
    }

    func testInvalidEmailWeakPasswordAndAppleCancellationKeepAnonymousSession() async throws {
        let anonymous = try await auth.signInAnonymously()
        let model = AccountLinkingModel(auth: auth)
        let invalidEmail = await model.linkEmail(email: "invalid", password: "Linked123!")
        XCTAssertFalse(invalidEmail)
        XCTAssertNotNil(model.errorMessage)
        let weakPassword = await model.linkEmail(email: uniqueEmail(), password: "123")
        XCTAssertFalse(weakPassword)
        XCTAssertNotNil(model.errorMessage)
        model.errorMessage = nil
        let cancelled = await model.completeApple(.failure(NSError(domain: ASAuthorizationError.errorDomain,
                                                                    code: ASAuthorizationError.canceled.rawValue)))
        XCTAssertFalse(cancelled)
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isWorking)
        XCTAssertEqual(auth.currentUser?.uid, anonymous.user.uid)
        XCTAssertTrue(try XCTUnwrap(auth.currentUser).isAnonymous)
    }

    func testGoogleAndAppleCredentialsLinkToTheSameAccount() async throws {
        let anonymous = try await auth.signInAnonymously()
        let model = AccountLinkingModel(auth: auth)
        let google = GoogleAuthProvider.credential(withIDToken: fakeIDToken(issuer: "https://accounts.google.com"), accessToken: "emulator")
        let googleLinked = await model.link(credential: google)
        XCTAssertTrue(googleLinked, model.errorMessage ?? "")
        XCTAssertEqual(auth.currentUser?.uid, anonymous.user.uid)
        let apple = OAuthProvider.credential(withProviderID: "apple.com", idToken: fakeIDToken(issuer: "https://appleid.apple.com"), rawNonce: "emulator")
        let appleLinked = await model.link(credential: apple)
        XCTAssertTrue(appleLinked, model.errorMessage ?? "")
        XCTAssertEqual(auth.currentUser?.uid, anonymous.user.uid)
        XCTAssertEqual(Set(auth.currentUser?.providerData.map(\.providerID) ?? []), ["google.com", "apple.com"])
        for credential in [google as AuthCredential, apple] {
            try auth.signOut()
            let restored = try await auth.signIn(with: credential)
            XCTAssertEqual(restored.user.uid, anonymous.user.uid)
        }
    }

    private func uniqueEmail() -> String { "pictune-\(UUID().uuidString)@example.invalid" }

    private func fakeIDToken(issuer: String) -> String {
        func encode(_ value: [String: Any]) -> String {
            let data = try! JSONSerialization.data(withJSONObject: value)
            return data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        return encode(["alg": "none"]) + "." + encode([
            "iss": issuer, "sub": UUID().uuidString, "aud": "demo-pictune-auth",
            "iat": Int(Date().timeIntervalSince1970), "exp": Int(Date().timeIntervalSince1970) + 3600
        ]) + "."
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Authentication did not reach the expected state")
    }
}
